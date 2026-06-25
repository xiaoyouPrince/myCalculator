if (!globalThis.__workHoursAutofillContentLoaded) {
  globalThis.__workHoursAutofillContentLoaded = true;

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === "WORK_HOURS_AUTOFILL_PING") {
      sendResponse({ ok: true });
      return true;
    }

    if (message?.type === "WORK_HOURS_AUTOFILL_DIAGNOSE") {
      const result = diagnosePage(message.records ?? []);
      sendResponse({ result });
      return true;
    }

    if (message?.type !== "WORK_HOURS_AUTOFILL") return false;

    autofillWorkHours(message.records ?? [], message.options ?? {})
      .then((result) => sendResponse({ result }))
      .catch((error) => sendResponse({
        result: {
          filled: 0,
          skipped: 0,
          failed: 1,
          candidates: 0,
          error: error instanceof Error ? error.message : String(error)
        }
      }));
    return true;
  });
}

async function autofillWorkHours(records, options) {
  const recordByDay = new Map(records.map((record) => [record.day, record]));
  const yearMonth = inferVisibleYearMonth(records);
  const candidates = findDateInputCandidates(yearMonth);

  let filled = 0;
  let skipped = 0;
  let failed = 0;
  const usedInputs = new Set();
  const details = [];

  for (const candidate of candidates) {
    const record = recordByDay.get(candidate.day);
    if (!record) {
      skipped += 1;
      continue;
    }

    const input = findWritableInputNear(candidate.anchor, usedInputs) ?? findMonthlyDayInput(candidate.day, usedInputs);
    if (!input) {
      skipped += 1;
      continue;
    }

    const value = formatFillValue(record, options);
    const written = await setInputValue(input, value);
    usedInputs.add(input);
    if (written) {
      filled += 1;
    } else {
      failed += 1;
    }
    details.push({
      day: candidate.day,
      targetValue: value,
      actualValue: input.value,
      inputId: input.id ?? "",
      inputName: input.getAttribute("name") ?? "",
      ok: written
    });
  }

  return { filled, skipped, failed, candidates: candidates.length, details };
}

function diagnosePage(records) {
  const yearMonth = inferVisibleYearMonth(records);
  const candidates = findDateInputCandidates(yearMonth);
  const writableInputs = [...document.querySelectorAll("input, textarea")].filter(isWritableTextInput);
  const monthlyDetailInputs = findMonthlyDetailInputs();

  return {
    url: location.href,
    inferredYearMonth: yearMonth,
    importedRecordDays: records.map((record) => record.day).slice(0, 40),
    candidateCount: candidates.length,
    monthlyDetailInputCount: monthlyDetailInputs.length,
    monthlyDetailInputs: monthlyDetailInputs.slice(0, 31).map((input, index) => ({
      day: index + 1,
      selector: describeElement(input),
      id: input.id ?? "",
      name: input.getAttribute("name") ?? "",
      value: input.value ?? ""
    })),
    candidates: candidates.slice(0, 40).map((candidate) => {
      const input = findWritableInputNear(candidate.anchor, new Set()) ?? findMonthlyDayInput(candidate.day, new Set());
      return {
        day: candidate.day,
        anchorText: sampleText(candidate.anchor),
        anchorSelector: describeElement(candidate.anchor),
        nearbyInputSelector: input ? describeElement(input) : null,
        nearbyInputPlaceholder: input?.getAttribute("placeholder") ?? "",
        nearbyInputName: input?.getAttribute("name") ?? "",
        nearbyInputId: input?.id ?? ""
      };
    }),
    writableInputCount: writableInputs.length,
    writableInputs: writableInputs.slice(0, 40).map((input) => ({
      selector: describeElement(input),
      type: input.getAttribute("type") || input.tagName.toLowerCase(),
      name: input.getAttribute("name") ?? "",
      id: input.id ?? "",
      placeholder: input.getAttribute("placeholder") ?? "",
      value: input.value ?? ""
    })),
    tableSamples: [...document.querySelectorAll("tr")].slice(0, 8).map((row) => sampleText(row)),
    bodySample: sampleText(document.body, 500)
  };
}

function inferVisibleYearMonth(records) {
  const text = document.body.innerText;
  const slashMatch = text.match(/(20\d{2})\s*[/-年]\s*(\d{1,2})/);
  if (slashMatch) {
    return {
      year: Number(slashMatch[1]),
      month: Number(slashMatch[2])
    };
  }

  const firstDay = records[0]?.day;
  if (firstDay) {
    const [year, month] = firstDay.split("-").map(Number);
    return { year, month };
  }

  const now = new Date();
  return { year: now.getFullYear(), month: now.getMonth() + 1 };
}

function findDateInputCandidates({ year, month }) {
  const rows = [...document.querySelectorAll("tr")];
  const rowCandidates = rows.flatMap((row) => candidatesFromRow(row, year, month));
  if (rowCandidates.length) return dedupeCandidates(rowCandidates);

  const cells = [...document.querySelectorAll("td, th, [role='cell'], [role='gridcell']")];
  return dedupeCandidates(cells.flatMap((cell) => candidatesFromDateAnchor(cell, year, month)));
}

function candidatesFromRow(row, year, month) {
  const cells = [...row.children];
  const result = [];
  for (const cell of cells) {
    result.push(...candidatesFromDateAnchor(cell, year, month));
  }
  return result;
}

function candidatesFromDateAnchor(anchor, year, month) {
  const text = normalizeText(anchor.innerText || anchor.textContent || "");
  const day = parseDayText(text);
  if (!day) return [];

  return [{
    day: `${year}-${pad2(month)}-${pad2(day)}`,
    anchor
  }];
}

function parseDayText(text) {
  const trimmed = text.trim();
  if (!trimmed) return null;

  const fullDate = trimmed.match(/\b20\d{2}[-/.年](\d{1,2})[-/.月](\d{1,2})/);
  if (fullDate) return Number(fullDate[2]);

  const dayOnly = trimmed.match(/^(?:\D*)?([1-9]|[12]\d|3[01])(?:\D*)?$/);
  if (dayOnly) return Number(dayOnly[1]);

  return null;
}

function findWritableInputNear(anchor, usedInputs) {
  const sameCellInput = firstWritableInput(anchor.querySelectorAll("input, textarea"), usedInputs);
  if (sameCellInput) return sameCellInput;

  const row = anchor.closest("tr");
  if (row) {
    const rowInputs = [...row.querySelectorAll("input, textarea")];
    const anchorIndex = [...row.children].indexOf(anchor.closest("td, th") ?? anchor);
    const inputsAfterAnchor = rowInputs.filter((input) => {
      const inputCell = input.closest("td, th");
      return inputCell ? [...row.children].indexOf(inputCell) >= anchorIndex : true;
    });
    return firstWritableInput(inputsAfterAnchor, usedInputs) ?? firstWritableInput(rowInputs, usedInputs);
  }

  const container = anchor.closest("td, th, [role='cell'], [role='gridcell'], div, section");
  if (container) {
    const input = firstWritableInput(container.querySelectorAll("input, textarea"), usedInputs);
    if (input) return input;
  }

  return nearestFollowingInput(anchor, usedInputs);
}

function firstWritableInput(inputs, usedInputs) {
  return [...inputs].find((input) => isWritableTextInput(input) && !usedInputs.has(input)) ?? null;
}

function findMonthlyDayInput(dayText, usedInputs) {
  const day = Number(dayText.split("-")[2]);
  if (!Number.isInteger(day) || day < 1 || day > 31) return null;

  const input = findMonthlyDetailInputs()[day - 1] ?? null;
  return input && !usedInputs.has(input) ? input : null;
}

function findMonthlyDetailInputs() {
  const detailInputs = [...document.querySelectorAll("input.wf-input-detail")]
    .filter(isWritableTextInput)
    .filter((input) => input.classList.contains("wf-input-3"))
    .filter((input) => /^field\d+_\d+$/.test(input.id || input.name || ""));

  if (detailInputs.length >= 31) {
    return detailInputs.slice(0, 31);
  }

  const numericFieldInputs = [...document.querySelectorAll("input[id^='field'][name^='field']")]
    .filter(isWritableTextInput)
    .filter((input) => {
      const idNumber = Number((input.id.match(/^field(\d+)_/) ?? [])[1]);
      return idNumber >= 13169 && idNumber <= 13229;
    });

  return numericFieldInputs
    .sort((left, right) => fieldNumber(left) - fieldNumber(right))
    .slice(0, 31);
}

function fieldNumber(input) {
  return Number(((input.id || input.name || "").match(/^field(\d+)_/) ?? [])[1]) || 0;
}

async function setInputValue(input, value) {
  const beforeValue = input.value;
  const prototype = input.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
  const valueSetter = Object.getOwnPropertyDescriptor(prototype, "value")?.set;

  input.scrollIntoView({ block: "center", inline: "nearest" });
  input.focus();
  input.click();
  selectInputText(input);

  dispatchTextEvent(input, "keydown", value);
  dispatchBeforeInput(input, value);

  const inserted = document.execCommand?.("insertText", false, value);
  if (!inserted || input.value !== value) {
    if (input._valueTracker) {
      input._valueTracker.setValue(beforeValue);
    }
    if (valueSetter) {
      valueSetter.call(input, value);
    } else {
      input.value = value;
    }
  }

  input.setAttribute("value", value);
  dispatchInputEvents(input, value);
  triggerJQueryEvents(input, value);
  input.blur();
  input.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
  await waitForFrame();

  if (input.value !== value) {
    input.focus();
    selectInputText(input);
    if (valueSetter) {
      valueSetter.call(input, value);
    } else {
      input.value = value;
    }
    input.setAttribute("value", value);
    dispatchInputEvents(input, value);
    triggerJQueryEvents(input, value);
    input.blur();
    input.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
    await waitForFrame();
  }

  return input.value === value;
}

function selectInputText(input) {
  if (typeof input.select === "function") {
    input.select();
    return;
  }
  if (typeof input.setSelectionRange === "function") {
    input.setSelectionRange(0, input.value.length);
  }
}

function dispatchInputEvents(input, value) {
  input.dispatchEvent(new InputEvent("input", {
    bubbles: true,
    cancelable: true,
    inputType: "insertText",
    data: value
  }));
  dispatchTextEvent(input, "keyup", value);
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

function dispatchBeforeInput(input, value) {
  input.dispatchEvent(new InputEvent("beforeinput", {
    bubbles: true,
    cancelable: true,
    inputType: "insertText",
    data: value
  }));
}

function dispatchTextEvent(input, type, value) {
  input.dispatchEvent(new KeyboardEvent(type, {
    bubbles: true,
    cancelable: true,
    key: value.slice(-1) || "0"
  }));
}

function triggerJQueryEvents(input, value) {
  const jquery = globalThis.jQuery || globalThis.$;
  if (typeof jquery !== "function") return;
  try {
    jquery(input).val(value).trigger("input").trigger("change").trigger("blur");
  } catch {
    // Ignore pages that expose a non-jQuery `$`.
  }
}

function waitForFrame() {
  return new Promise((resolve) => {
    requestAnimationFrame(() => setTimeout(resolve, 0));
  });
}

function nearestFollowingInput(anchor, usedInputs) {
  const inputs = [...document.querySelectorAll("input, textarea")].filter((input) => isWritableTextInput(input) && !usedInputs.has(input));
  const anchorRect = anchor.getBoundingClientRect();
  return inputs
    .map((input) => ({ input, rect: input.getBoundingClientRect() }))
    .filter(({ rect }) => rect.top >= anchorRect.top - 8)
    .sort((a, b) => {
      const ad = Math.abs(a.rect.top - anchorRect.top) + Math.abs(a.rect.left - anchorRect.left);
      const bd = Math.abs(b.rect.top - anchorRect.top) + Math.abs(b.rect.left - anchorRect.left);
      return ad - bd;
    })[0]?.input ?? null;
}

function isWritableTextInput(input) {
  if (input.disabled || input.readOnly) return false;
  if (input.tagName === "TEXTAREA") return true;
  const type = (input.getAttribute("type") || "text").toLowerCase();
  return ["", "text", "number", "tel", "search"].includes(type);
}

function formatFillValue(record, options) {
  if (options.fillMode === "range") {
    return `${record.startTime}-${record.endTime}`;
  }
  return workHours(record.startTime, record.endTime).toFixed(options.precision === 1 ? 1 : 2);
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

function dedupeCandidates(candidates) {
  const seen = new Set();
  return candidates.filter((candidate) => {
    if (seen.has(candidate.day)) return false;
    seen.add(candidate.day);
    return true;
  });
}

function normalizeText(text) {
  return text.replace(/\s+/g, " ").trim();
}

function pad2(value) {
  return String(value).padStart(2, "0");
}

function sampleText(element, limit = 120) {
  return normalizeText(element.innerText || element.textContent || "").slice(0, limit);
}

function describeElement(element) {
  const tag = element.tagName.toLowerCase();
  const id = element.id ? `#${cssEscape(element.id)}` : "";
  const classes = [...element.classList].slice(0, 4).map((name) => `.${cssEscape(name)}`).join("");
  const name = element.getAttribute("name") ? `[name="${element.getAttribute("name")}"]` : "";
  return `${tag}${id}${classes}${name}`;
}

function cssEscape(value) {
  if (globalThis.CSS?.escape) return CSS.escape(value);
  return String(value).replace(/[^a-zA-Z0-9_-]/g, "\\$&");
}
