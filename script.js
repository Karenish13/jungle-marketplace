/* JUNGLE MARKETPLACE */

/*
Current prototype:
Home page is functional.
Seller and buyer features are under development.
JUNGLE focuses on phones and tablets.
*/

// Titles and descriptions for future pages
const pages = {
    "explore-page": {
        title: "Find Parts",
        message:
            "Coming Soon! You'll be able to explore replacement " +
            "parts for phones and tablets."
    },

    "listings-page": {
        title: "My Listings",
        message:
            "Coming Soon! You'll be able to view and manage " +
            "your device listings here."
    },

    "profile-page": {
        title: "Profile",
        message:
            "Coming Soon! Account and profile features " +
            "are still under development."
    },

    "search-page": {
        title: "Marketplace Search",
        message:
            "Coming Soon! Marketplace search will help " +
            "you find phones, tablets, and replacement parts."
    },

    "phones-page": {
        title: "Phones",
        message:
            "Coming Soon! Browse phone devices and " +
            "replacement parts here."
    },

    "tablets-page": {
        title: "Tablets",
        message:
            "Coming Soon! Browse tablet devices and " +
            "replacement parts here."
    }
};

// Navigate between screens
function showPage(pageId) {
    const homePage =
        document.getElementById("home-page");

    const sellPage =
        document.getElementById("sell-page");

    const comingSoonPage =
        document.getElementById("coming-soon-page");

    // Hide everything first, then reveal the right view
    homePage.hidden = true;
    sellPage.hidden = true;
    comingSoonPage.hidden = true;

    if (pageId === "home-page") {
        homePage.hidden = false;
    } else if (pageId === "sell-page") {
        sellPage.hidden = false;
        startDiagnostic();
    } else if (pages[pageId]) {
        document.getElementById(
            "coming-soon-title"
        ).textContent = pages[pageId].title;

        document.getElementById(
            "coming-soon-message"
        ).textContent = pages[pageId].message;

        comingSoonPage.hidden = false;
    } else {
        homePage.hidden = false;
    }

    window.scrollTo({
        top: 0,
        behavior: "smooth"
    });
}

// Search placeholder
function searchMarketplace() {
    showPage("search-page");
}

// Category placeholders
function filterCategory(category) {
    if (category === "Phones") {
        showPage("phones-page");
    } else if (category === "Tablets") {
        showPage("tablets-page");
    }
}

/* ============================================
   SELL A DEVICE: DIAGNOSTIC QUESTIONNAIRE
   ============================================
   Each option has:
     label  - text shown to the seller
     points - 0 (worst) to 3 (best), used for the condition score
     flag   - optional tag that triggers a note or override in the result
   Questions with scored: false are collected but not scored.
*/

const diagnosticQuestions = [
    {
        id: "type",
        title: "What kind of device are you selling?",
        scored: false,
        options: [
            { label: "Phone" },
            { label: "Tablet" }
        ]
    },
    {
        id: "brand",
        title: "Who makes it?",
        scored: false,
        options: [
            { label: "Apple" },
            { label: "Samsung" },
            { label: "Google" },
            { label: "Other brand" }
        ]
    },
    {
        id: "power",
        title: "Does it turn on?",
        help: "Try holding the power button for 10 seconds.",
        options: [
            { label: "Yes, it starts normally", points: 3 },
            { label: "Only while plugged in", points: 1 },
            { label: "No, it won't turn on", points: 0, flag: "noPower" }
        ]
    },
    {
        id: "screenDamage",
        title: "What does the screen glass look like?",
        options: [
            { label: "No scratches or cracks", points: 3 },
            { label: "Light scratches only", points: 2 },
            { label: "Cracked, but still usable", points: 1, flag: "cracked" },
            { label: "Badly shattered", points: 0, flag: "cracked" }
        ]
    },
    {
        id: "display",
        title: "How does the display and touch work?",
        help: "Check for lines, dead spots, flickering, or burn-in.",
        options: [
            { label: "Works perfectly", points: 3 },
            { label: "Minor issues, like a faint spot or slight discoloration", points: 2 },
            { label: "Dead zones, lines, or unresponsive touch", points: 0 }
        ]
    },
    {
        id: "body",
        title: "What shape is the body in?",
        options: [
            { label: "Like new", points: 3 },
            { label: "Light scuffs or scratches", points: 2 },
            { label: "Dents or deep scratches", points: 1 },
            { label: "Bent, cracked, or missing pieces", points: 0 }
        ]
    },
    {
        id: "battery",
        title: "How is the battery?",
        options: [
            { label: "Lasts a full day or close to it", points: 3 },
            { label: "Drains quickly", points: 1 },
            { label: "Barely holds a charge", points: 0 },
            { label: "Swollen, or the case is bulging", points: 0, flag: "swollen" }
        ]
    },
    {
        id: "cameras",
        title: "Do the cameras work?",
        options: [
            { label: "All cameras work", points: 3 },
            { label: "Some cameras or the flash don't work", points: 1 },
            { label: "None of them work", points: 0 }
        ]
    },
    {
        id: "audio",
        title: "Do the speakers and microphone work?",
        options: [
            { label: "Everything works", points: 3 },
            { label: "Sound is distorted or one part fails", points: 1 },
            { label: "No sound or no microphone", points: 0 }
        ]
    },
    {
        id: "ports",
        title: "Do the charging port and buttons work?",
        options: [
            { label: "All work", points: 3 },
            { label: "Some are loose, sticky, or unreliable", points: 1 },
            { label: "Charging doesn't work, or buttons are broken", points: 0 }
        ]
    },
    {
        id: "water",
        title: "Has it been exposed to water or moisture?",
        options: [
            { label: "No", points: 3 },
            { label: "Not sure", points: 1, flag: "waterMaybe" },
            { label: "Yes", points: 0, flag: "water" }
        ]
    },
    {
        id: "lock",
        title: "Is the device free of account locks?",
        help: "For example Apple ID, Google account, or a carrier lock.",
        options: [
            { label: "Yes, I've signed out and wiped it", points: 3 },
            { label: "No, I'm still signed in", points: 1, flag: "signedIn" },
            { label: "It's locked and I can't get in", points: 0, flag: "locked" }
        ]
    },
    {
        id: "accessories",
        title: "What's included with it?",
        options: [
            { label: "Original box and charger", points: 3 },
            { label: "Charger or cable only", points: 2 },
            { label: "Just the device", points: 1 }
        ]
    }
];

const diagnosticState = {
    step: 0,
    answers: {},   // questionId -> index of selected option
    done: false
};

function startDiagnostic() {
    diagnosticState.step = 0;
    diagnosticState.answers = {};
    diagnosticState.done = false;
    renderDiagnostic();
}

function renderDiagnostic() {
    const root = document.getElementById("diagnostic-root");

    if (diagnosticState.done) {
        root.innerHTML = buildResultHTML();
        return;
    }

    const total = diagnosticQuestions.length;
    const step = diagnosticState.step;
    const question = diagnosticQuestions[step];
    const selected = diagnosticState.answers[question.id];
    const percent = Math.round((step / total) * 100);
    const isLast = step === total - 1;

    const optionsHTML = question.options.map((option, index) => `
        <label class="diag-option">
            <input
                type="radio"
                name="${question.id}"
                value="${index}"
                ${selected === index ? "checked" : ""}
                onchange="selectAnswer('${question.id}', ${index})"
            >
            <span>${option.label}</span>
        </label>
    `).join("");

    root.innerHTML = `
        <div class="diag-progress-label">
            <span>Question ${step + 1} of ${total}</span>
            <span>${percent}%</span>
        </div>
        <div class="diag-progress"
             role="progressbar"
             aria-valuemin="0"
             aria-valuemax="100"
             aria-valuenow="${percent}">
            <div class="diag-progress-bar" style="width: ${percent}%"></div>
        </div>

        <fieldset class="diag-question">
            <legend>${question.title}</legend>
            ${question.help ? `<p class="diag-help">${question.help}</p>` : ""}
            <div class="diag-options">${optionsHTML}</div>
        </fieldset>

        <div class="diag-nav">
            <button type="button" class="secondary"
                    onclick="${step === 0 ? "showPage('home-page')" : "prevQuestion()"}">
                ${step === 0 ? "Cancel" : "Back"}
            </button>
            <button type="button" id="diag-next"
                    onclick="nextQuestion()"
                    ${selected === undefined ? "disabled" : ""}>
                ${isLast ? "See my results" : "Next"}
            </button>
        </div>
    `;
}

function selectAnswer(questionId, optionIndex) {
    diagnosticState.answers[questionId] = optionIndex;

    // Enable Next without re-rendering, so focus stays on the option
    const next = document.getElementById("diag-next");
    if (next) next.disabled = false;
}

function nextQuestion() {
    const question = diagnosticQuestions[diagnosticState.step];
    if (diagnosticState.answers[question.id] === undefined) return;

    if (diagnosticState.step === diagnosticQuestions.length - 1) {
        diagnosticState.done = true;
    } else {
        diagnosticState.step++;
    }

    renderDiagnostic();
    window.scrollTo({ top: 0, behavior: "smooth" });
}

function prevQuestion() {
    if (diagnosticState.step > 0) {
        diagnosticState.step--;
        renderDiagnostic();
    }
}

// Work out the grade, notes, and recommended path
function evaluateDiagnostic() {
    let earned = 0;
    let possible = 0;
    const flags = new Set();

    diagnosticQuestions.forEach(question => {
        const index = diagnosticState.answers[question.id];
        const option = question.options[index];

        if (option.flag) flags.add(option.flag);

        if (question.scored !== false) {
            earned += option.points;
            possible += 3;
        }
    });

    const percent = earned / possible;

    let grade;
    if (percent >= 0.85) grade = "excellent";
    else if (percent >= 0.65) grade = "good";
    else if (percent >= 0.40) grade = "fair";
    else grade = "parts";

    // Serious problems cap the grade no matter what the score says
    if (flags.has("noPower") || flags.has("swollen") || flags.has("locked")) {
        grade = "parts";
    } else if (flags.has("water") && (grade === "excellent" || grade === "good")) {
        grade = "fair";
    }

    return { grade, flags, percent: Math.round(percent * 100) };
}

const gradeInfo = {
    excellent: {
        css: "",
        label: "Excellent condition",
        heading: "Ready to sell as a working device",
        text: "Your device is in great shape and should appeal to buyers looking for a dependable phone or tablet."
    },
    good: {
        css: "",
        label: "Good condition",
        heading: "Ready to sell as a working device",
        text: "Your device works well with some signs of wear. It's a good fit for buyers who want a working device at a lower price."
    },
    fair: {
        css: "fair",
        label: "Fair condition",
        heading: "Sell as working with disclosed issues, or sell for repair",
        text: "Your device has noticeable issues. Be upfront about them in your listing, or list it as a repair project."
    },
    parts: {
        css: "parts",
        label: "Parts or repair",
        heading: "Best suited for parts or repair",
        text: "Your device likely needs repair. Its working components could still help someone fix their own phone or tablet."
    }
};

const flagNotes = {
    swollen: { danger: true, text: "A swollen battery is a fire risk. Stop charging the device and don't ship it yourself. Take it to a battery recycling drop-off." },
    noPower: { text: "Because the device doesn't turn on, buyers will treat it as a repair or parts listing." },
    water: { text: "Water exposure can cause hidden damage that shows up later. This must be disclosed in your listing." },
    waterMaybe: { text: "If you suspect water exposure, say so in your listing so buyers know what to expect." },
    locked: { text: "Devices locked to an account can't be resold as working. Try recovering the account with the manufacturer first." },
    signedIn: { text: "Sign out of your accounts and erase the device before you hand it over." },
    cracked: { text: "Cracked glass should be mentioned in your listing and photos." }
};

function buildResultHTML() {
    const { grade, flags, percent } = evaluateDiagnostic();
    const info = gradeInfo[grade];

    // Notes, with safety warnings first
    const noteKeys = Object.keys(flagNotes).filter(key => flags.has(key));
    const dangerNotes = noteKeys.filter(key => flagNotes[key].danger);
    const otherNotes = noteKeys.filter(key => !flagNotes[key].danger);

    const notesHTML = (keys, extraClass) => keys.length ? `
        <div class="diag-notes ${extraClass}" role="note">
            <ul>${keys.map(key => `<li>${flagNotes[key].text}</li>`).join("")}</ul>
        </div>` : "";

    // Summary of the seller's answers
    const summaryHTML = diagnosticQuestions.map(question => {
        const option = question.options[diagnosticState.answers[question.id]];
        return `<div><dt>${question.title.replace(/\?$/, "")}</dt><dd>${option.label}</dd></div>`;
    }).join("");

    return `
        <div class="diag-result">
            <span class="diag-grade ${info.css}">${info.label} · ${percent}% score</span>
            <h2>${info.heading}</h2>
            <p>${info.text}</p>

            ${notesHTML(dangerNotes, "danger")}
            ${notesHTML(otherNotes, "")}

            <dl class="diag-summary">${summaryHTML}</dl>

            <p>Price estimates and listing tools are coming soon.</p>

            <div class="diag-actions">
                <button type="button" class="diag-secondary" onclick="startDiagnostic()">
                    Start over
                </button>
                <button type="button" onclick="showPage('home-page')">
                    Back to Home
                </button>
            </div>
        </div>
    `;
}

// Allow Enter key to trigger search
document.addEventListener("DOMContentLoaded", () => {
    const searchInput =
        document.getElementById("marketplace-search");

    if (searchInput) {
        searchInput.addEventListener("keydown", event => {
            if (event.key === "Enter") {
                searchMarketplace();
            }
        });
    }

    // Always begin on the homepage
    showPage("home-page");
});
