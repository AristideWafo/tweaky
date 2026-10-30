(() => {
  // DOM Elements - Stage & Panel
  const scenarioTabs = document.querySelectorAll(".scenario-tab");
  const orbitNodes = document.querySelectorAll(".orbit-node");
  const simStage = document.getElementById("sim-stage");
  const realCaptureView = document.getElementById("real-capture-view");
  const toggleRealShotBtn = document.getElementById("toggle-real-shot-btn");
  const backToInteractiveBtn = document.getElementById("back-to-interactive-btn");
  const replayDemoBtn = document.getElementById("replay-demo-btn");

  const simAppName = document.getElementById("sim-app-name");
  const simShortcutStep = document.getElementById("sim-shortcut-step");
  const simMenubarIcon = document.getElementById("sim-menubar-icon");
  const simSourceBadge = document.getElementById("sim-source-badge");
  const simSourceText = document.getElementById("sim-source-text");
  const simSourceStatus = document.getElementById("sim-source-status");

  const tweakyLivePanel = document.getElementById("tweaky-live-panel");
  const tpShortcutPill = document.getElementById("tp-shortcut-pill");
  const tpSourceLabel = document.getElementById("tp-source-label");
  const tpInput = document.getElementById("tp-input");
  const tpBtnCorrect = document.getElementById("tp-btn-correct");
  const tpBtnTranslate = document.getElementById("tp-btn-translate");
  const tpBtnPaste = document.getElementById("tp-btn-paste");
  const tpBtnOcr = document.getElementById("tp-btn-ocr");
  const tpResetBtn = document.getElementById("tp-reset-btn");

  const tpResultContainer = document.getElementById("tp-result-container");
  const tpResultText = document.getElementById("tp-result-text");
  const tpBtnCopy = document.getElementById("tp-btn-copy");
  const tpBtnReplace = document.getElementById("tp-btn-replace");
  const tpSpinner = document.getElementById("tp-spinner");
  const tpStatusText = document.getElementById("tp-status-text");

  // Clipped Asset Tutorial Elements
  const tutStepBtns = document.querySelectorAll(".tut-step-btn");
  const clippedAssetImg = document.getElementById("clipped-asset-img");
  const assetSpotlightRing = document.getElementById("asset-spotlight-ring");
  const assetCursor = document.getElementById("asset-cursor");
  const tutCaptionBadge = document.getElementById("tut-caption-badge");
  const tutCaptionText = document.getElementById("tut-caption-text");

  const TUTORIAL_STEPS = [
    {
      step: 1,
      clipClass: "clip-step-1",
      spotlight: {
        left: "3.4%",
        top: "15.8%",
        width: "93.2%",
        height: "24.5%",
        badge: "1. ⌥ Space · Texte capturé"
      },
      cursor: { left: "29%", top: "9%", click: false },
      badgeText: "Étape 1 / 4",
      captionHtml:
        "Sélectionnez votre texte et appuyez sur <strong>⌥ Space</strong> : Tweaky s'ouvre avec la phrase déjà chargée."
    },
    {
      step: 2,
      clipClass: "clip-step-2",
      spotlight: {
        left: "3.1%",
        top: "42.5%",
        width: "15.4%",
        height: "10.6%",
        badge: "2. ⌘↩ · Correct"
      },
      cursor: { left: "11%", top: "48%", click: true },
      badgeText: "Étape 2 / 4",
      captionHtml:
        "Le panneau dévoile ses actions : appuyez sur <strong>⌘↩</strong> (ou cliquez sur <em>Correct</em>)."
    },
    {
      step: 3,
      clipClass: "clip-step-3",
      spotlight: {
        left: "3.1%",
        top: "59.5%",
        width: "74.5%",
        height: "14.8%",
        badge: "3. Streaming ~1 s · Résultat"
      },
      cursor: { left: "48%", top: "68%", click: false },
      badgeText: "Étape 3 / 4",
      captionHtml:
        "Le panneau se déplie et streame la correction : <em>« ça fait quand même déjà 3 h que tu la crées, la branche »</em>."
    },
    {
      step: 4,
      clipClass: "clip-step-4",
      spotlight: {
        left: "56.5%",
        top: "75.5%",
        width: "40.6%",
        height: "11.5%",
        badge: "4. ⌘↩ Remplacer · ⇧⌘C Copier"
      },
      cursor: { left: "82%", top: "81%", click: true },
      badgeText: "Étape 4 / 4",
      captionHtml:
        "Appuyez à nouveau sur <strong>⌘↩</strong> pour remplacer la sélection directement dans l'application d'origine."
    }
  ];

  // State
  let currentApp = {
    name: "Slack",
    sample: "ca fais quand mm déjà 3 de temps que tu crées la branche la",
    corrected: "ça fait quand même déjà 3 h que tu la crées, la branche",
    translated: "it's honestly been 3 hours already that you've been creating that branch"
  };

  let currentScenario = "screenshot";
  let currentTutStep = 1;
  let currentProviderName = "Google Gemini";
  let activeTimers = [];

  function clearTimers() {
    activeTimers.forEach((id) => clearTimeout(id));
    activeTimers = [];
    simMenubarIcon.classList.remove("pulsing");
    tweakyLivePanel.classList.remove("dimmed-instant");
    tpSpinner.classList.remove("active");
    tpBtnCorrect.classList.remove("pressing");
    tpBtnTranslate.classList.remove("pressing");
    tpBtnReplace.classList.remove("pressing");
    tpBtnOcr.classList.remove("pressing");
  }

  function later(fn, ms) {
    const id = setTimeout(fn, ms);
    activeTimers.push(id);
    return id;
  }

  // Stream text word by word like SSE
  function streamWords(targetEl, fullText, speedMs, onComplete) {
    const words = fullText.split(" ");
    targetEl.innerHTML = '<span class="streaming-cursor"></span>';
    let index = 0;

    function nextWord() {
      if (index < words.length) {
        const currentSlice = words.slice(0, index + 1).join(" ");
        targetEl.innerHTML = "";
        const textNode = document.createTextNode(currentSlice);
        const cursor = document.createElement("span");
        cursor.className = "streaming-cursor";
        targetEl.appendChild(textNode);
        targetEl.appendChild(cursor);
        index += 1;
        later(nextWord, speedMs);
      } else {
        targetEl.textContent = fullText;
        if (onComplete) onComplete();
      }
    }

    nextWord();
  }

  function showInteractiveStage(show) {
    if (show) {
      simStage.style.display = "block";
      realCaptureView.classList.remove("visible");
      toggleRealShotBtn.textContent = "Voir le tutoriel clippé (Asset macOS)";
    } else {
      simStage.style.display = "none";
      realCaptureView.classList.add("visible");
      toggleRealShotBtn.textContent = "Ouvrir le simulateur interactif";
    }
  }

  function applyTutorialStep(stepNumber, autoAdvance = true) {
    clearTimers();
    currentTutStep = stepNumber;
    const cfg = TUTORIAL_STEPS.find((s) => s.step === stepNumber) || TUTORIAL_STEPS[0];

    tutStepBtns.forEach((btn) => {
      const isMatch = Number(btn.dataset.tutStep) === cfg.step;
      btn.classList.remove("active");
      if (isMatch) {
        // Trigger reflow so the CSS progress bar restarts cleanly
        void btn.offsetWidth;
        btn.classList.add("active");
      }
    });

    if (clippedAssetImg) {
      clippedAssetImg.classList.remove("clip-step-1", "clip-step-2", "clip-step-3", "clip-step-4");
      clippedAssetImg.classList.add(cfg.clipClass);
    }

    if (assetSpotlightRing) {
      assetSpotlightRing.style.left = cfg.spotlight.left;
      assetSpotlightRing.style.top = cfg.spotlight.top;
      assetSpotlightRing.style.width = cfg.spotlight.width;
      assetSpotlightRing.style.height = cfg.spotlight.height;
      assetSpotlightRing.setAttribute("data-badge", cfg.spotlight.badge);
    }

    if (assetCursor) {
      assetCursor.style.left = cfg.cursor.left;
      assetCursor.style.top = cfg.cursor.top;
      assetCursor.classList.remove("clicking");
      if (cfg.cursor.click) {
        later(() => assetCursor.classList.add("clicking"), 520);
        later(() => assetCursor.classList.remove("clicking"), 820);
      }
    }

    if (tutCaptionBadge) tutCaptionBadge.textContent = cfg.badgeText;
    if (tutCaptionText) tutCaptionText.innerHTML = cfg.captionHtml;

    if (autoAdvance) {
      const nextStep = cfg.step < 4 ? cfg.step + 1 : 1;
      later(() => {
        if (currentScenario === "screenshot") {
          applyTutorialStep(nextStep, true);
        }
      }, 2650);
    }
  }

  // Run one of the 5 demo scenarios
  function runScenario(scenario) {
    clearTimers();
    currentScenario = scenario;

    scenarioTabs.forEach((tab) => {
      const isMatch = tab.dataset.scenario === scenario;
      tab.classList.toggle("active", isMatch);
      tab.setAttribute("aria-selected", isMatch ? "true" : "false");
    });

    if (scenario === "screenshot") {
      showInteractiveStage(false);
      applyTutorialStep(1, true);
      return;
    }

    showInteractiveStage(true);
    simAppName.textContent = currentApp.name;
    simSourceBadge.textContent = `${currentApp.name} · Sélection active`;
    simSourceText.textContent = currentApp.sample;
    simSourceText.classList.remove("replaced");
    simSourceStatus.textContent = "Sélectionné";

    if (scenario === "correct") {
      tpShortcutPill.textContent = "⌥ Space";
      tpSourceLabel.textContent = "Selection";
      tpInput.value = currentApp.sample;
      tpResultContainer.classList.add("tp-result-Area-hidden");
      tpResultText.textContent = "";
      tpStatusText.textContent = "Sélection capturée via Accessibilité.";
      simShortcutStep.textContent = "1. ⌥ Space (Panneau ouvert)";

      later(() => {
        tpBtnCorrect.classList.add("pressing");
        simShortcutStep.textContent = "2. ⌘↩ (Correct)";
        tpStatusText.textContent = `Contacting ${currentProviderName}…`;
        tpSpinner.classList.add("active");
      }, 650);

      later(() => {
        tpBtnCorrect.classList.remove("pressing");
        tpResultContainer.classList.remove("tp-result-Area-hidden");
        tpBtnReplace.disabled = true;
        streamWords(tpResultText, currentApp.corrected, 55, () => {
          tpSpinner.classList.remove("active");
          tpStatusText.textContent = "Done.";
          tpBtnReplace.disabled = false;
          simShortcutStep.textContent = "3. ⌘↩ (Prêt à remplacer)";

          later(() => {
            tpBtnReplace.classList.add("pressing");
            simShortcutStep.textContent = "4. ⌘↩ (Replace Selection)";
          }, 950);

          later(() => {
            tpBtnReplace.classList.remove("pressing");
            simSourceText.textContent = currentApp.corrected;
            simSourceText.classList.add("replaced");
            simSourceStatus.textContent = "✓ Remplacé en place";
            tpStatusText.textContent = `Done. Replaced in ${currentApp.name}.`;
          }, 1250);
        });
      }, 1150);
    } else if (scenario === "instant") {
      // PR feat/instant-tweak: ⌥ ⇧ Space corrects in place without opening the panel
      tpShortcutPill.textContent = "⌥ ⇧ Space";
      tpSourceLabel.textContent = "Instant Correct (Sans panneau)";
      tpInput.value = currentApp.sample;
      tpResultContainer.classList.remove("tp-result-Area-hidden");
      tpResultText.textContent = "Mode Option-Maj-Espace : le panneau reste fermé pendant que l'icône de la barre des menus pulse.";
      tweakyLivePanel.classList.add("dimmed-instant");

      simShortcutStep.textContent = "1. ⌥ ⇧ Space pressé";
      simSourceStatus.textContent = " Pulsation barre des menus…";
      simMenubarIcon.classList.add("pulsing");
      tpSpinner.classList.add("active");
      tpStatusText.textContent = `Instant tweak via ${currentProviderName} (OutputGuard actif)…`;

      later(() => {
        simMenubarIcon.classList.remove("pulsing");
        tpSpinner.classList.remove("active");
        simSourceText.textContent = currentApp.corrected;
        simSourceText.classList.add("replaced");
        simSourceStatus.textContent = "✓ Corrigé sur place (~0.9 s)";
        simShortcutStep.textContent = "✓ Remplacé sans ouvrir Tweaky";
        tpResultText.textContent = currentApp.corrected;
        tpStatusText.textContent = "Done. OutputGuard: longueur et format validés.";
      }, 1450);
    } else if (scenario === "translate") {
      tpShortcutPill.textContent = "⌥ Space";
      tpSourceLabel.textContent = "Selection";
      tpInput.value = currentApp.sample;
      tpResultContainer.classList.add("tp-result-Area-hidden");
      tpStatusText.textContent = "Sélection prête à traduire.";
      simShortcutStep.textContent = "1. ⌥ Space → ⌘T (Translate)";

      later(() => {
        tpBtnTranslate.classList.add("pressing");
        tpSpinner.classList.add("active");
        tpStatusText.textContent = `Contacting ${currentProviderName}…`;
      }, 500);

      later(() => {
        tpBtnTranslate.classList.remove("pressing");
        tpResultContainer.classList.remove("tp-result-Area-hidden");
        tpBtnReplace.disabled = true;
        streamWords(tpResultText, currentApp.translated, 50, () => {
          tpSpinner.classList.remove("active");
          tpStatusText.textContent = "Done.";
          tpBtnReplace.disabled = false;
          simShortcutStep.textContent = "✓ Traduit en continu (⌘↩ pour remplacer)";
        });
      }, 950);
    } else if (scenario === "ocr") {
      tpShortcutPill.textContent = "⌥ Space";
      tpSourceLabel.textContent = "Screen OCR";
      tpInput.value = "";
      tpResultContainer.classList.add("tp-result-Area-hidden");
      tpBtnOcr.classList.add("pressing");
      tpSpinner.classList.add("active");
      tpStatusText.textContent = "Reading the main display locally…";
      simShortcutStep.textContent = "ScreenCaptureKit + Apple Vision (Local)";

      later(() => {
        tpBtnOcr.classList.remove("pressing");
        tpSpinner.classList.remove("active");
        const ocrSample = "Erreur de build #402 : La signature Developer ID requiert un certificat valide dans le trousseau.";
        tpInput.value = ocrSample;
        simSourceText.textContent = "[Texte extrait d'une capture d'écran via Vision OCR]";
        simSourceStatus.textContent = "OCR local terminé";
        tpStatusText.textContent = "OCR complete. Review the text before sending it.";
      }, 1050);
    }
  }

  // Smart fallback transformations when the user edits the textarea manually
  function smartTransform(rawText, action) {
    const trimmed = rawText.trim();
    if (!trimmed) return "";

    if (trimmed === currentApp.sample) {
      return action === "correct" ? currentApp.corrected : currentApp.translated;
    }

    if (action === "correct") {
      return trimmed
        .replace(/\bca fais\b/gi, "ça fait")
        .replace(/\bquand mm\b/gi, "quand même")
        .replace(/\b3 de temps\b/gi, "3 h")
        .replace(/\bpr\b/g, "pour")
        .replace(/\bdes que\b/gi, "dès que")
        .replace(/\breunion\b/gi, "réunion")
        .replace(/\bverifier\b/gi, "vérifier")
        .replace(/\bdependance\b/gi, "dépendance")
        .replace(/\bselection\b/gi, "sélection")
        .replace(/([a-zà-ÿ])$/i, "$1.");
    }

    // Simple French -> English demonstration fallback for custom user text
    return `[EN] ${trimmed}`;
  }

  // Interactive Panel Buttons
  tpBtnCorrect.addEventListener("click", () => {
    clearTimers();
    const input = tpInput.value.trim();
    if (!input) return;
    tpSpinner.classList.add("active");
    tpStatusText.textContent = `Contacting ${currentProviderName}…`;
    tpResultContainer.classList.remove("tp-result-Area-hidden");
    tpBtnReplace.disabled = true;

    const output = smartTransform(input, "correct");
    later(() => {
      streamWords(tpResultText, output, 45, () => {
        tpSpinner.classList.remove("active");
        tpStatusText.textContent = "Done.";
        tpBtnReplace.disabled = false;
      });
    }, 320);
  });

  tpBtnTranslate.addEventListener("click", () => {
    clearTimers();
    const input = tpInput.value.trim();
    if (!input) return;
    tpSpinner.classList.add("active");
    tpStatusText.textContent = `Contacting ${currentProviderName}…`;
    tpResultContainer.classList.remove("tp-result-Area-hidden");
    tpBtnReplace.disabled = true;

    const output = smartTransform(input, "translate");
    later(() => {
      streamWords(tpResultText, output, 45, () => {
        tpSpinner.classList.remove("active");
        tpStatusText.textContent = "Done.";
        tpBtnReplace.disabled = false;
      });
    }, 320);
  });

  tpBtnPaste.addEventListener("click", () => {
    clearTimers();
    tpSourceLabel.textContent = "Clipboard";
    tpInput.value = "On se retrouve a 14h pour valider le deploiement sur Vercel et verifier les tests Swift.";
    currentApp = {
      name: "Presse-papiers",
      sample: tpInput.value,
      corrected: "On se retrouve à 14 h pour valider le déploiement sur Vercel et vérifier les tests Swift.",
      translated: "Let's meet at 2 PM to validate the Vercel deployment and check the Swift tests."
    };
    tpStatusText.textContent = "Text loaded from the clipboard.";
  });

  tpBtnOcr.addEventListener("click", () => {
    runScenario("ocr");
  });

  tpBtnCopy.addEventListener("click", () => {
    const text = tpResultText.textContent.trim();
    if (!text) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).catch(() => {});
    }
    tpStatusText.textContent = "Result copied.";
  });

  tpBtnReplace.addEventListener("click", () => {
    const text = tpResultText.textContent.trim();
    if (!text) return;
    simSourceText.textContent = text;
    simSourceText.classList.add("replaced");
    simSourceStatus.textContent = "✓ Remplacé en place";
    tpStatusText.textContent = `Done. Replaced selection in ${currentApp.name}.`;
  });

  tpResetBtn.addEventListener("click", () => {
    clearTimers();
    tpInput.value = "";
    tpResultText.textContent = "";
    tpResultContainer.classList.add("tp-result-Area-hidden");
    tpSourceLabel.textContent = "Manual input";
    tpStatusText.textContent = "Prêt — Saisissez du texte ou choisissez un scénario.";
  });

  // Scenario Tab Clicks
  scenarioTabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      runScenario(tab.dataset.scenario);
    });
  });

  // Clipped Asset Tutorial Step Button Clicks
  tutStepBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      const stepNum = Number(btn.dataset.tutStep) || 1;
      applyTutorialStep(stepNum, true);
    });
  });

  // Orbit App Nodes Clicks
  orbitNodes.forEach((node) => {
    node.addEventListener("click", () => {
      orbitNodes.forEach((n) => n.classList.remove("active"));
      node.classList.add("active");
      currentApp = {
        name: node.dataset.app,
        sample: node.dataset.sample,
        corrected: node.dataset.corrected,
        translated: node.dataset.translated
      };
      runScenario(currentScenario === "screenshot" ? "correct" : currentScenario);
    });
  });

  // Replay & Toggle Clipped Tutorial / Simulator Buttons
  replayDemoBtn.addEventListener("click", () => {
    runScenario(currentScenario);
  });

  toggleRealShotBtn.addEventListener("click", () => {
    const isShowingReal = realCaptureView.classList.contains("visible");
    if (isShowingReal) {
      runScenario("correct");
    } else {
      runScenario("screenshot");
    }
  });

  backToInteractiveBtn.addEventListener("click", () => {
    runScenario("correct");
  });

  // Interactive Settings Window Provider Selector
  const swProviderSelect = document.getElementById("sw-provider-select");
  const swModelDisplay = document.getElementById("sw-model-display");
  const providerDefaults = {
    gemini: { name: "Google Gemini", model: "gemini-3.5-flash" },
    openai: { name: "OpenAI", model: "gpt-5-mini" },
    anthropic: { name: "Anthropic", model: "claude-sonnet-4-5" },
    compatible: { name: "OpenAI-compatible", model: "llama-3.3-70b (localhost)" }
  };

  if (swProviderSelect && swModelDisplay) {
    swProviderSelect.addEventListener("change", () => {
      const info = providerDefaults[swProviderSelect.value] || providerDefaults.gemini;
      currentProviderName = info.name;
      swModelDisplay.textContent = info.model;
    });
  }

  // Provider Preference Chips in Bottom Waitlist
  const providerChips = document.querySelectorAll(".provider-chip");
  let selectedWaitlistProvider = "Google Gemini";
  providerChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      providerChips.forEach((c) => c.classList.remove("selected"));
      chip.classList.add("selected");
      selectedWaitlistProvider = chip.dataset.provider;
    });
  });

  // Waitlist Form Handling
  function handleWaitlistSubmit(formEl, inputEl, feedbackEl) {
    formEl.addEventListener("submit", (e) => {
      e.preventDefault();
      const email = inputEl.value.trim();
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

      if (!emailRegex.test(email)) {
        feedbackEl.textContent = "Veuillez saisir une adresse e-mail valide.";
        feedbackEl.classList.add("visible");
        inputEl.focus();
        return;
      }

      // Store in localStorage for instant persistence
      const stored = JSON.parse(localStorage.getItem("tweaky_waitlist") || "[]");
      if (!stored.some((entry) => entry.email.toLowerCase() === email.toLowerCase())) {
        stored.push({
          email,
          provider: selectedWaitlistProvider,
          joinedAt: new Date().toISOString()
        });
        localStorage.setItem("tweaky_waitlist", JSON.stringify(stored));
      }

      inputEl.value = "";
      feedbackEl.innerHTML =
        `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#4F3FE6" stroke-width="2.3">` +
        `<path d="M20 6L9 17l-5-5" stroke-linecap="round" stroke-linejoin="round"/></svg>` +
        `<span>Merci ! <strong>${email}</strong> est inscrit sur la liste d'attente (${selectedWaitlistProvider}).</span>`;
      feedbackEl.classList.add("visible");
    });
  }

  const heroForm = document.getElementById("hero-waitlist-form");
  const heroEmail = document.getElementById("hero-email");
  const heroFeedback = document.getElementById("hero-waitlist-feedback");
  if (heroForm && heroEmail && heroFeedback) {
    handleWaitlistSubmit(heroForm, heroEmail, heroFeedback);
  }

  const bottomForm = document.getElementById("bottom-waitlist-form");
  const bottomEmail = document.getElementById("bottom-email");
  const bottomFeedback = document.getElementById("bottom-waitlist-feedback");
  if (bottomForm && bottomEmail && bottomFeedback) {
    handleWaitlistSubmit(bottomForm, bottomEmail, bottomFeedback);
  }

  // FAQ Accordion
  const faqItems = document.querySelectorAll(".faq-item");
  faqItems.forEach((item) => {
    const btn = item.querySelector(".faq-question");
    if (btn) {
      btn.addEventListener("click", () => {
        item.classList.toggle("open");
      });
    }
  });

  // Live Keyboard Shortcuts on the Page (⌥ Space, ⌥ ⇧ Space, ⌘↩, ⌘T, ⇧⌘C, Esc)
  document.addEventListener("keydown", (e) => {
    const activeTag = document.activeElement ? document.activeElement.tagName : "";
    const isEmailInput =
      document.activeElement === heroEmail || document.activeElement === bottomEmail;
    if (isEmailInput) return;

    // ⌥ ⇧ Space -> Instant Tweak scenario
    if (e.altKey && e.shiftKey && e.code === "Space") {
      e.preventDefault();
      runScenario("instant");
      return;
    }

    // ⌥ Space -> Open / Replay Panel scenario
    if (e.altKey && !e.shiftKey && e.code === "Space") {
      e.preventDefault();
      runScenario("correct");
      return;
    }

    // ⌘↩ -> Correct first, then Replace Selection once result is ready (exact TweakyPanel.swift behavior)
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      e.preventDefault();
      const hasResult =
        !tpResultContainer.classList.contains("tp-result-Area-hidden") &&
        tpResultText.textContent.trim().length > 0 &&
        !tpBtnReplace.disabled;
      if (hasResult) {
        tpBtnReplace.click();
      } else {
        tpBtnCorrect.click();
      }
      return;
    }

    // ⇧⌘C -> Copy Result
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === "c") {
      if (tpResultText.textContent.trim().length > 0) {
        e.preventDefault();
        tpBtnCopy.click();
      }
      return;
    }

    // Esc -> Reset panel when textarea is focused
    if (e.key === "Escape" && activeTag === "TEXTAREA") {
      e.preventDefault();
      tpResetBtn.click();
    }
  });

  // Start the initial Clipped Asset Tutorial animation on page load
  later(() => {
    runScenario("screenshot");
  }, 200);
})();
