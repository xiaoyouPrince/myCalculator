const STORAGE_KEY = "workScheduleRecords";

const fileInput = document.getElementById("fileInput");
const dataStatus = document.getElementById("dataStatus");
const fillMode = document.getElementById("fillMode");
const precision = document.getElementById("precision");
const autofillButton = document.getElementById("autofillButton");
const diagnoseButton = document.getElementById("diagnoseButton");
const clearButton = document.getElementById("clearButton");
const message = document.getElementById("message");
const diagnoseOutput = document.getElementById("diagnoseOutput");

init();

async function init() {
  const { [STORAGE_KEY]: records = [] } = await chrome.storage.local.get(STORAGE_KEY);
  renderStatus(records);
}

fileInput.addEventListener("change", async () => {
  const file = fileInput.files?.[0];
  if (!file) return;

  try {
    const text = await file.text();
    const records = normalizeRecords(JSON.parse(text));
    await chrome.storage.local.set({ [STORAGE_KEY]: records });
    renderStatus(records);
    showMessage(`已导入 ${records.length} 条工作记录`, "ok");
  } catch (error) {
    showMessage(error instanceof Error ? error.message : "导入失败", "error");
  } finally {
    fileInput.value = "";
  }
});

autofillButton.addEventListener("click", async () => {
  const { [STORAGE_KEY]: records = [] } = await chrome.storage.local.get(STORAGE_KEY);
  if (!records.length) {
    showMessage("请先导入极简 JSON", "error");
    return;
  }

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) {
    showMessage("无法获取当前页面", "error");
    return;
  }

  try {
    await ensureContentScript(tab.id);
    const options = {
      fillMode: fillMode.value,
      precision: Number(precision.value)
    };
    const { result: contentResult } = await chrome.tabs.sendMessage(tab.id, {
      type: "WORK_HOURS_AUTOFILL",
      records,
      options
    });
    const result = contentResult.failed ? await autofillInMainWorld(tab.id, records, options) : contentResult;
    const failedText = result.failed ? `，写入失败 ${result.failed} 项` : "";
    showMessage(`已确认写入 ${result.filled} 项，跳过 ${result.skipped} 项${failedText}`, result.failed ? "error" : "ok");
    if (result.details?.length) {
      diagnoseOutput.value = JSON.stringify(result.details, null, 2);
    }
  } catch (error) {
    showMessage(readableTabError(error), "error");
  }
});

diagnoseButton.addEventListener("click", async () => {
  const { [STORAGE_KEY]: records = [] } = await chrome.storage.local.get(STORAGE_KEY);
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) {
    showMessage("无法获取当前页面", "error");
    return;
  }

  try {
    await ensureContentScript(tab.id);
    const { result } = await chrome.tabs.sendMessage(tab.id, {
      type: "WORK_HOURS_AUTOFILL_DIAGNOSE",
      records
    });
    diagnoseOutput.value = JSON.stringify(result, null, 2);
    showMessage("已生成诊断结果", "ok");
  } catch (error) {
    showMessage(readableTabError(error), "error");
  }
});

clearButton.addEventListener("click", async () => {
  await chrome.storage.local.remove(STORAGE_KEY);
  renderStatus([]);
  diagnoseOutput.value = "";
  showMessage("已清空导入数据", "ok");
});

function normalizeRecords(value) {
  if (!Array.isArray(value)) {
    throw new Error("JSON 顶层必须是数组");
  }

  return value.map((record) => {
    const day = String(record.day ?? "").trim();
    const startTime = String(record.startTime ?? "").trim();
    const endTime = String(record.endTime ?? "").trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
      throw new Error(`日期格式无效：${day}`);
    }
    if (!/^\d{2}:\d{2}$/.test(startTime) || !/^\d{2}:\d{2}$/.test(endTime)) {
      throw new Error(`时间格式无效：${day}`);
    }
    return { day, startTime, endTime };
  });
}

function renderStatus(records) {
  dataStatus.textContent = records.length ? `当前已导入 ${records.length} 条工作记录` : "未导入数据";
}

async function ensureContentScript(tabId) {
  try {
    await chrome.tabs.sendMessage(tabId, { type: "WORK_HOURS_AUTOFILL_PING" });
    return;
  } catch {
    await chrome.scripting.executeScript({
      target: { tabId, allFrames: true },
      files: ["content.js"]
    });
  }
}

async function autofillInMainWorld(tabId, records, options) {
  const results = await chrome.scripting.executeScript({
    target: { tabId, allFrames: true },
    world: "MAIN",
    func: mainWorldAutofill,
    args: [records, options]
  });
  return aggregateFrameResults(results.map((item) => item.result).filter(Boolean));
}

function aggregateFrameResults(results) {
  return results.reduce((best, result) => {
    if (!best || result.filled > best.filled || result.details.length > best.details.length) {
      return result;
    }
    return best;
  }, null) ?? { filled: 0, skipped: 0, failed: 0, candidates: 0, details: [] };
}

function mainWorldAutofill(records, options) {
  const inputs = findMonthlyDetailInputs();
  const pageYear = Number(document.querySelector("#field13023_0")?.value) || Number(records[0]?.day.split("-")[0]);
  const pageMonth = Number(document.querySelector("#field13024_0")?.value) || Number(records[0]?.day.split("-")[1]);
  const details = [];
  let filled = 0;
  let skipped = 0;
  let failed = 0;

  for (const record of records) {
    const [year, month, day] = record.day.split("-").map(Number);
    if (year !== pageYear || month !== pageMonth) {
      skipped += 1;
      continue;
    }

    const input = inputs[day - 1];
    if (!input) {
      skipped += 1;
      continue;
    }

    const targetValue = formatFillValue(record, options);
    const ok = setPageInputValue(input, targetValue);
    if (ok) {
      filled += 1;
    } else {
      failed += 1;
    }
    details.push({
      day: record.day,
      targetValue,
      actualValue: input.value,
      inputId: input.id || "",
      inputName: input.getAttribute("name") || "",
      ok
    });
  }

  return { filled, skipped, failed, candidates: inputs.length, details, mode: "main-world" };

  function findMonthlyDetailInputs() {
    const detailInputs = [...document.querySelectorAll("input.wf-input-detail")]
      .filter(isWritableTextInput)
      .filter((input) => input.classList.contains("wf-input-3"))
      .filter((input) => /^field\d+_\d+$/.test(input.id || input.name || ""));

    if (detailInputs.length >= 31) {
      return detailInputs.slice(0, 31);
    }

    return [...document.querySelectorAll("input[id^='field'][name^='field']")]
      .filter(isWritableTextInput)
      .filter((input) => {
        const idNumber = Number((input.id.match(/^field(\d+)_/) || [])[1]);
        return idNumber >= 13169 && idNumber <= 13229;
      })
      .sort((left, right) => fieldNumber(left) - fieldNumber(right))
      .slice(0, 31);
  }

  function setPageInputValue(input, value) {
    input.scrollIntoView({ block: "center", inline: "nearest" });
    input.focus();
    input.click();
    setNativeValue(input, "");
    emitInput(input, "");

    for (const char of value) {
      input.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, cancelable: true, key: char }));
      input.dispatchEvent(new InputEvent("beforeinput", {
        bubbles: true,
        cancelable: true,
        inputType: "insertText",
        data: char
      }));
      setNativeValue(input, input.value + char);
      input.dispatchEvent(new InputEvent("input", {
        bubbles: true,
        cancelable: true,
        inputType: "insertText",
        data: char
      }));
      input.dispatchEvent(new KeyboardEvent("keyup", { bubbles: true, cancelable: true, key: char }));
    }

    setNativeValue(input, value);
    input.setAttribute("value", value);
    emitInput(input, value);
    triggerJQuery(input, value);
    input.dispatchEvent(new Event("change", { bubbles: true }));
    input.blur();
    input.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
    return input.value === value;
  }

  function setNativeValue(input, value) {
    const prototype = input.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(prototype, "value")?.set;
    if (input._valueTracker) {
      input._valueTracker.setValue(input.value);
    }
    if (setter) {
      setter.call(input, value);
    } else {
      input.value = value;
    }
  }

  function emitInput(input, value) {
    input.dispatchEvent(new InputEvent("input", {
      bubbles: true,
      cancelable: true,
      inputType: "insertText",
      data: value
    }));
    input.dispatchEvent(new Event("propertychange", { bubbles: true }));
  }

  function triggerJQuery(input, value) {
    const jquery = globalThis.jQuery || globalThis.$;
    if (typeof jquery !== "function") return;
    try {
      jquery(input).val(value).trigger("input").trigger("propertychange").trigger("change").trigger("blur");
    } catch {
      // Ignore pages that expose a non-jQuery `$`.
    }
  }

  function isWritableTextInput(input) {
    if (input.disabled || input.readOnly) return false;
    const type = (input.getAttribute("type") || "text").toLowerCase();
    return ["", "text", "number", "tel", "search"].includes(type);
  }

  function fieldNumber(input) {
    return Number(((input.id || input.name || "").match(/^field(\d+)_/) || [])[1]) || 0;
  }

  function formatFillValue(record, fillOptions) {
    if (fillOptions.fillMode === "range") {
      return `${record.startTime}-${record.endTime}`;
    }
    return workHours(record.startTime, record.endTime).toFixed(fillOptions.precision === 1 ? 1 : 2);
  }

  function workHours(startTime, endTime) {
    const start = minutesFromTime(startTime);
    const end = minutesFromTime(endTime);
    return Math.max(0, end - start) / 60;
  }

  function minutesFromTime(text) {
    const [hour, minute] = text.split(":").map(Number);
    return hour * 60 + minute;
  }
}

function readableTabError(error) {
  const detail = error instanceof Error ? error.message : String(error ?? "");
  if (detail.includes("Cannot access") || detail.includes("The extensions gallery")) {
    return "当前页面是浏览器受限页面，扩展无法填写";
  }
  if (detail.includes("No tab with id")) {
    return "当前标签页已不可用，请重新打开页面";
  }
  return detail ? `当前页面暂不可填写：${detail}` : "当前页面暂不可填写";
}

function showMessage(text, type) {
  message.textContent = text;
  message.className = `message ${type}`;
}
