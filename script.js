/* JUNGLE MARKETPLACE */

// Placeholder pages that are still coming soon
const pages = {
    "explore-page": {
        title: "Find Parts",
        message:
            "Coming Soon! You'll be able to explore replacement " +
            "parts for phones and tablets."
    },

    "profile-page": {
        title: "Profile",
        message:
            "Coming Soon! Account and profile features " +
            "are still under development."
    }
};

// Pages that show a grid of listings
const browsePages = [
    "listings-page",
    "phones-page",
    "tablets-page",
    "search-page"
];

let currentSearch = "";

/* ============================================
   PRICING
   ============================================
   STARTING ESTIMATES, NOT LIVE DATA.
   price = typical used price in US dollars for a 128 GB device
           in excellent condition. Check these against recent sold
           listings and edit them freely.
*/

const devicePrices = [
    // Apple phones
    { brand: "Apple", type: "Phone", model: "iPhone 16", price: 550 },
    { brand: "Apple", type: "Phone", model: "iPhone 15", price: 430 },
    { brand: "Apple", type: "Phone", model: "iPhone 14", price: 330 },
    { brand: "Apple", type: "Phone", model: "iPhone 13", price: 260 },
    { brand: "Apple", type: "Phone", model: "iPhone 12", price: 190 },
    { brand: "Apple", type: "Phone", model: "iPhone 11", price: 130 },
    { brand: "Apple", type: "Phone", model: "iPhone SE (3rd gen)", price: 120 },

    // Samsung phones
    { brand: "Samsung", type: "Phone", model: "Galaxy S25", price: 520 },
    { brand: "Samsung", type: "Phone", model: "Galaxy S24", price: 400 },
    { brand: "Samsung", type: "Phone", model: "Galaxy S23", price: 290 },
    { brand: "Samsung", type: "Phone", model: "Galaxy S22", price: 200 },
    { brand: "Samsung", type: "Phone", model: "Galaxy S21", price: 150 },
    { brand: "Samsung", type: "Phone", model: "Galaxy A54", price: 170 },

    // Google phones
    { brand: "Google", type: "Phone", model: "Pixel 9", price: 420 },
    { brand: "Google", type: "Phone", model: "Pixel 8", price: 300 },
    { brand: "Google", type: "Phone", model: "Pixel 7", price: 190 },
    { brand: "Google", type: "Phone", model: "Pixel 6", price: 140 },

    // Apple tablets
    { brand: "Apple", type: "Tablet", model: "iPad Pro 11-inch (M4)", price: 700 },
    { brand: "Apple", type: "Tablet", model: "iPad Air (M2)", price: 420 },
    { brand: "Apple", type: "Tablet", model: "iPad (10th gen)", price: 240 },
    { brand: "Apple", type: "Tablet", model: "iPad (9th gen)", price: 150 },

    // Samsung tablets
    { brand: "Samsung", type: "Tablet", model: "Galaxy Tab S9", price: 400 },
    { brand: "Samsung", type: "Tablet", model: "Galaxy Tab S8", price: 280 },
    { brand: "Samsung", type: "Tablet", model: "Galaxy Tab A9+", price: 120 },

    // Google tablets
    { brand: "Google", type: "Tablet", model: "Pixel Tablet", price: 250 }
];

const OTHER_MODEL = "Other / not listed";

// Storage changes the price (keys match the storage question's labels)
const storageFactor = {
    "64 GB or less": 0.85,
    "128 GB": 1,
    "256 GB": 1.12,
    "512 GB or more": 1.25,
    "Not sure": 1
};

// Condition changes the price
const gradeFactor = {
    excellent: 1,
    good: 0.85,
    fair: 0.62,
    parts: 0.30
};

function roundToFive(n) {
    return Math.max(5, Math.round(n / 5) * 5);
}

// Returns { low, suggested, high } or null when the model isn't in the table
function estimatePrice(grade, flags) {
    const model = diagnosticState.answers.model;
    const device = devicePrices.find(d => d.model === model);
    if (!device || !gradeFactor[grade]) return null;

    let price = device.price *
        (storageFactor[getLabel("storage")] || 1) *
        gradeFactor[grade];

    if (flags.has("carrierLocked")) price *= 0.95;

    return {
        low: roundToFive(price * 0.9),
        suggested: roundToFive(price),
        high: roundToFive(price * 1.1)
    };
}

function formatPrice(n) {
    return "$" + Number(n).toLocaleString();
}

/* ============================================
   LISTINGS STORAGE (this browser only)
   ============================================ */

const LISTINGS_KEY = "jungle-listings";

function loadListings() {
    try {
        return JSON.parse(localStorage.getItem(LISTINGS_KEY)) || [];
    } catch (error) {
        return [];
    }
}

function saveListings(list) {
    localStorage.setItem(LISTINGS_KEY, JSON.stringify(list));
}

function markSold(id) {
    const list = loadListings();
    const listing = list.find(l => l.id === id);
    if (listing) {
        listing.status = "sold";
        saveListings(list);
    }
    showPage("listings-page");
}

function deleteListing(id) {
    if (!confirm("Delete this listing?")) return;
    saveListings(loadListings().filter(l => l.id !== id));
    showPage("listings-page");
}

/* ============================================
   NAVIGATION
   ============================================ */

function showPage(pageId) {
    const homePage = document.getElementById("home-page");
    const sellPage = document.getElementById("sell-page");
    const browsePage = document.getElementById("browse-page");
    const comingSoonPage = document.getElementById("coming-soon-page");

    homePage.hidden = true;
    sellPage.hidden = true;
    browsePage.hidden = true;
    comingSoonPage.hidden = true;

    if (pageId === "home-page") {
        renderHomeFeed();
        homePage.hidden = false;
    } else if (pageId === "sell-page") {
        startDiagnostic();
        sellPage.hidden = false;
    } else if (browsePages.includes(pageId)) {
        renderBrowse(pageId);
        browsePage.hidden = false;
    } else if (pages[pageId]) {
        document.getElementById("coming-soon-title").textContent =
            pages[pageId].title;
        document.getElementById("coming-soon-message").textContent =
            pages[pageId].message;
        comingSoonPage.hidden = false;
    } else {
        renderHomeFeed();
        homePage.hidden = false;
    }

    window.scrollTo({ top: 0, behavior: "smooth" });
}

function searchMarketplace() {
    const input = document.getElementById("marketplace-search");
    currentSearch = input ? input.value.trim() : "";
    showPage("search-page");
}

function filterCategory(category) {
    if (category === "Phones") {
        showPage("phones-page");
    } else if (category === "Tablets") {
        showPage("tablets-page");
    }
}

/* ============================================
   BROWSING LISTINGS
   ============================================ */

function escapeHTML(text) {
    return String(text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function listingCardHTML(listing, mine) {
    const info = gradeInfo[listing.grade] || gradeInfo.good;

    const image = listing.photos && listing.photos[0]
        ? `<img src="${listing.photos[0]}" alt="${escapeHTML(listing.title)}">`
        : `<div class="listing-noimg">${listing.type === "Tablet" ? "📟" : "📱"}</div>`;

    const actions = mine ? `
        <div class="listing-actions">
            ${listing.status === "active" ? `
                <button type="button" class="diag-secondary"
                        onclick="markSold('${listing.id}')">Mark as sold</button>` : ""}
            <button type="button" class="diag-secondary"
                    onclick="deleteListing('${listing.id}')">Delete</button>
        </div>` : "";

    return `
        <article class="listing-card ${listing.status === "sold" ? "sold" : ""}">
            ${image}
            <div class="listing-body">
                <div class="listing-price">
                    ${formatPrice(listing.price)}
                    ${listing.status === "sold" ? `<span class="status">Sold</span>` : ""}
                </div>
                <h3>${escapeHTML(listing.title)}</h3>
                <span class="diag-grade ${info.css}">${info.label}</span>
                <details>
                    <summary>Details</summary>
                    <p class="listing-desc">${escapeHTML(listing.description)}</p>
                </details>
                ${actions}
            </div>
        </article>`;
}

function renderBrowse(pageId) {
    const root = document.getElementById("browse-root");
    const mine = pageId === "listings-page";
    let title = "My Listings";
    let list = loadListings();

    if (!mine) {
        list = list.filter(l => l.status === "active");
    }

    if (pageId === "phones-page") {
        title = "Phones";
        list = list.filter(l => l.type === "Phone");
    } else if (pageId === "tablets-page") {
        title = "Tablets";
        list = list.filter(l => l.type === "Tablet");
    } else if (pageId === "search-page") {
        title = currentSearch
            ? `Results for “${escapeHTML(currentSearch)}”`
            : "All listings";
        const query = currentSearch.toLowerCase();
        list = list.filter(l =>
            !query ||
            (l.title + " " + l.description + " " + l.brand + " " + l.model)
                .toLowerCase().includes(query)
        );
    }

    const body = list.length
        ? `<div class="listing-grid">${list.map(l => listingCardHTML(l, mine)).join("")}</div>`
        : `<div class="coming-soon-content">
               <span class="coming-soon-icon">🌱</span>
               <p>${mine ? "You haven't posted anything yet." : "No listings here yet."}</p>
               <button type="button" onclick="showPage('sell-page')">Sell a Device</button>
           </div>`;

    root.innerHTML = `
        <h2>${title}</h2>
        ${body}
        <div class="diag-actions" style="margin-top: 24px;">
            <button type="button" class="diag-secondary" onclick="showPage('home-page')">
                Back to Home
            </button>
        </div>`;
}

function renderHomeFeed() {
    const feed = document.getElementById("home-feed");
    if (!feed) return;

    const recent = loadListings()
        .filter(l => l.status === "active")
        .slice(0, 4);

    if (!recent.length) {
        feed.innerHTML = `
            <div class="marketplace-preview">
                <span class="preview-icon">♻️</span>
                <h3>Be the First to List</h3>
                <p>
                    Nothing is listed yet. Answer a few questions about your
                    device and post it in minutes.
                </p>
                <button type="button" onclick="showPage('sell-page')">
                    Sell a Device
                </button>
            </div>`;
        return;
    }

    feed.innerHTML = `
        <div class="listing-grid">
            ${recent.map(l => listingCardHTML(l, false)).join("")}
        </div>`;
}

/* ============================================
   SELL A DEVICE: DIAGNOSTIC QUESTIONNAIRE
   ============================================
   Question fields:
     weight  - how much the question counts toward the score
     scored  - false means collected but not scored
     input   - "select" for a dropdown built from devicePrices

   Option fields:
     label   - text shown to the seller
     points  - 0 (worst) to 3 (best)
     flag    - triggers a note or a grade override
     issue   - added to the listing's known issues
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
        id: "model",
        title: "What's the model?",
        help: "Model and storage are two of the biggest factors in value. Pick \"Other / not listed\" if yours isn't here.",
        input: "select",
        scored: false
    },
    {
        id: "storage",
        title: "How much storage does it have?",
        help: "You can find this in Settings > About.",
        scored: false,
        options: [
            { label: "64 GB or less" },
            { label: "128 GB" },
            { label: "256 GB" },
            { label: "512 GB or more" },
            { label: "Not sure" }
        ]
    },
    {
        id: "carrier",
        title: "What's its carrier and payment status?",
        scored: false,
        options: [
            { label: "Unlocked, works with any carrier" },
            { label: "Locked to one carrier", flag: "carrierLocked", issue: "Carrier-locked" },
            { label: "Still being paid off", flag: "financed", issue: "Still financed" },
            { label: "Reported lost, stolen, or blocked", flag: "blocked" }
        ]
    },
    {
        id: "power",
        title: "Does it turn on?",
        help: "Try holding the power button for 10 seconds.",
        weight: 3,
        options: [
            { label: "Yes, it starts normally", points: 3 },
            { label: "Only while plugged in", points: 1, issue: "Only powers on while plugged in" },
            { label: "No, it won't turn on", points: 0, flag: "noPower", issue: "Does not power on" }
        ]
    },
    {
        id: "screenDamage",
        title: "What does the screen glass look like?",
        help: "Remove any screen protector first and check the glass itself.",
        weight: 3,
        options: [
            { label: "No scratches or cracks", points: 3 },
            { label: "Light scratches only", points: 2, issue: "Light screen scratches" },
            { label: "Cracked, but still usable", points: 1, flag: "cracked", issue: "Cracked screen" },
            { label: "Badly shattered", points: 0, flag: "screenBad", issue: "Badly shattered screen" }
        ]
    },
    {
        id: "display",
        title: "How do the display and touch work?",
        help: "Check for lines, dead pixels, flickering, burn-in, or touch that responds on its own.",
        weight: 3,
        options: [
            { label: "Works perfectly", points: 3 },
            { label: "Minor issues, like a faint spot or slight discoloration", points: 2, issue: "Minor display flaws" },
            { label: "Dead zones, lines, or unresponsive touch", points: 0, flag: "screenBad", issue: "Display or touch faults" }
        ]
    },
    {
        id: "body",
        title: "What shape is the body in?",
        help: "Light wear matters less to buyers than things that don't work.",
        weight: 1,
        options: [
            { label: "Like new", points: 3 },
            { label: "Light scuffs or scratches", points: 2, issue: "Light scuffs on the body" },
            { label: "Dents, chipped corners, or cracked back glass", points: 1, issue: "Dents or cracked back glass" },
            { label: "Bent frame or missing pieces", points: 0, flag: "bent", issue: "Bent frame or missing pieces" }
        ]
    },
    {
        id: "battery",
        title: "How is the battery?",
        weight: 2,
        options: [
            { label: "Lasts a full day or close to it", points: 3 },
            { label: "Drains quickly or shuts down unexpectedly", points: 1, issue: "Weak battery" },
            { label: "Barely holds a charge, or overheats", points: 0, issue: "Battery needs replacing" },
            { label: "Swollen, or the case is bulging", points: 0, flag: "swollen", issue: "Swollen battery" }
        ]
    },
    {
        id: "charging",
        title: "Do charging and the buttons work?",
        help: "Test with a cable you know works. Include wireless charging if the model has it.",
        weight: 2,
        options: [
            { label: "Everything works", points: 3 },
            { label: "Charges slowly, only at an angle, or wireless charging fails", points: 1, issue: "Charging problems" },
            { label: "Won't charge, or buttons are broken", points: 0, issue: "Charging port or buttons need repair" }
        ]
    },
    {
        id: "cameras",
        title: "Do the cameras work?",
        weight: 2,
        options: [
            { label: "All cameras and the flash work", points: 3 },
            { label: "Some cameras or the flash don't work", points: 1, issue: "Some cameras not working" },
            { label: "None of them work", points: 0, issue: "Cameras not working" }
        ]
    },
    {
        id: "audio",
        title: "Do the speakers and microphone work?",
        weight: 1,
        options: [
            { label: "Everything works", points: 3 },
            { label: "Sound is distorted or one part fails", points: 1, issue: "Speaker or microphone problems" },
            { label: "No sound or no microphone", points: 0, issue: "No sound or microphone" }
        ]
    },
    {
        id: "biometrics",
        title: "Do Face ID or the fingerprint sensor work?",
        weight: 2,
        options: [
            { label: "Yes", points: 3 },
            { label: "It's unreliable", points: 1, issue: "Face ID or fingerprint unreliable" },
            { label: "No", points: 0, issue: "Face ID or fingerprint not working" },
            { label: "This device doesn't have one", points: 3 }
        ]
    },
    {
        id: "connectivity",
        title: "Do Wi-Fi, Bluetooth, and calls work?",
        weight: 2,
        options: [
            { label: "All work", points: 3 },
            { label: "One of them is unreliable", points: 1, issue: "Wi-Fi, Bluetooth, or calling is unreliable" },
            { label: "One or more don't work", points: 0, issue: "Wi-Fi, Bluetooth, or calling not working" }
        ]
    },
    {
        id: "water",
        title: "Has it been exposed to water or moisture?",
        help: "Water damage can show up later as corrosion, speaker distortion, or camera fogging.",
        weight: 3,
        options: [
            { label: "No", points: 3 },
            { label: "Not sure", points: 1, flag: "waterMaybe", issue: "Possible water exposure" },
            { label: "Yes", points: 0, flag: "water", issue: "Water exposure" }
        ]
    },
    {
        id: "lock",
        title: "Is the device free of account locks?",
        help: "For example Apple ID with Find My turned on, or a Google account.",
        weight: 3,
        options: [
            { label: "Yes, I've signed out and wiped it", points: 3 },
            { label: "No, I'm still signed in", points: 1, flag: "signedIn" },
            { label: "It's locked and I can't get in", points: 0, flag: "locked", issue: "Account-locked" }
        ]
    },
    {
        id: "accessories",
        title: "What's included with it?",
        help: "Accessories are nice to have, but they don't change the condition grade.",
        scored: false,
        options: [
            { label: "Original box and charger" },
            { label: "Charger or cable only" },
            { label: "Just the device" }
        ]
    }
];

const diagnosticState = {
    step: 0,
    view: "question",   // "question" | "result" | "listing" | "posted"
    answers: {},        // questionId -> option index, or text for the model
    result: null,
    draft: null
};

// The text of a selected choice, e.g. getLabel("storage") -> "128 GB"
function getLabel(questionId) {
    const question = diagnosticQuestions.find(q => q.id === questionId);
    const answer = diagnosticState.answers[questionId];
    if (answer === undefined) return "";
    return question.input ? answer : question.options[answer].label;
}

function isAnswered(question) {
    return diagnosticState.answers[question.id] !== undefined;
}

function answerLabel(question) {
    return escapeHTML(getLabel(question.id));
}

// Models that match the chosen device type and brand
function modelChoices() {
    const type = getLabel("type");
    const brand = getLabel("brand");
    const models = devicePrices
        .filter(d => d.type === type && d.brand === brand)
        .map(d => d.model);
    models.push(OTHER_MODEL);
    return models;
}

function startDiagnostic() {
    diagnosticState.step = 0;
    diagnosticState.view = "question";
    diagnosticState.answers = {};
    diagnosticState.result = null;
    diagnosticState.draft = null;
    renderDiagnostic();
}

function renderDiagnostic() {
    const root = document.getElementById("diagnostic-root");

    if (diagnosticState.view === "result") {
        root.innerHTML = buildResultHTML();
        return;
    }
    if (diagnosticState.view === "listing") {
        root.innerHTML = buildListingFormHTML();
        renderPhotoPreview();
        return;
    }
    if (diagnosticState.view === "posted") {
        root.innerHTML = buildPostedHTML();
        return;
    }

    const total = diagnosticQuestions.length;
    const step = diagnosticState.step;
    const question = diagnosticQuestions[step];
    const selected = diagnosticState.answers[question.id];
    const percent = Math.round((step / total) * 100);
    const isLast = step === total - 1;

    let answerHTML;

    if (question.input === "select") {
        answerHTML = `
            <select class="diag-text"
                    aria-label="${question.title}"
                    onchange="selectText('${question.id}', this.value)">
                <option value="">Choose a model</option>
                ${modelChoices().map(model => `
                    <option value="${escapeHTML(model)}" ${selected === model ? "selected" : ""}>
                        ${escapeHTML(model)}
                    </option>`).join("")}
            </select>`;
    } else {
        answerHTML = `<div class="diag-options">` +
            question.options.map((option, index) => `
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
            `).join("") + `</div>`;
    }

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
            ${answerHTML}
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

    // A new device type or brand makes the old model choice invalid
    if (questionId === "type" || questionId === "brand") {
        delete diagnosticState.answers.model;
    }

    const next = document.getElementById("diag-next");
    if (next) next.disabled = false;
}

function selectText(questionId, value) {
    if (value) {
        diagnosticState.answers[questionId] = value;
    } else {
        delete diagnosticState.answers[questionId];
    }

    const next = document.getElementById("diag-next");
    if (next) next.disabled = !value;
}

function nextQuestion() {
    const question = diagnosticQuestions[diagnosticState.step];
    if (!isAnswered(question)) return;

    if (diagnosticState.step === diagnosticQuestions.length - 1) {
        diagnosticState.result = evaluateDiagnostic();
        diagnosticState.view = "result";
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

const gradeOrder = ["parts", "fair", "good", "excellent"];

function capGrade(grade, max) {
    return gradeOrder.indexOf(grade) > gradeOrder.indexOf(max) ? max : grade;
}

function evaluateDiagnostic() {
    let earned = 0;
    let possible = 0;
    const flags = new Set();
    const issues = [];

    diagnosticQuestions.forEach(question => {
        if (question.input) return;

        const option = question.options[diagnosticState.answers[question.id]];

        if (option.flag) flags.add(option.flag);
        if (option.issue) issues.push(option.issue);

        if (question.scored !== false) {
            const weight = question.weight || 1;
            earned += option.points * weight;
            possible += 3 * weight;
        }
    });

    const percent = earned / possible;

    let grade;
    if (percent >= 0.85) grade = "excellent";
    else if (percent >= 0.65) grade = "good";
    else if (percent >= 0.40) grade = "fair";
    else grade = "parts";

    if (flags.has("water") || flags.has("screenBad") || flags.has("bent")) {
        grade = capGrade(grade, "fair");
    }
    if (flags.has("noPower") || flags.has("swollen") || flags.has("locked")) {
        grade = "parts";
    }
    if (flags.has("blocked")) {
        grade = "blocked";
    }

    return {
        grade,
        flags,
        issues,
        percent: Math.round(percent * 100),
        estimate: grade === "blocked" ? null : estimatePrice(grade, flags)
    };
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
        text: "Your device works well with some signs of wear. Light wear lowers value less than things that don't work."
    },
    fair: {
        css: "fair",
        label: "Fair condition",
        heading: "Sell with the issues disclosed, or as a repair project",
        text: "Your device has noticeable issues. Be upfront about them, since buyers who like to fix devices will price in the repair."
    },
    parts: {
        css: "parts",
        label: "Parts or repair",
        heading: "Best suited as a repair project or for parts",
        text: "Your device likely needs repair. Its working components could still help someone fix their own phone or tablet."
    },
    blocked: {
        css: "parts",
        label: "Can't list yet",
        heading: "This device isn't ready to list",
        text: "Devices reported lost, stolen, or blocked can't be sold. If this is a mistake, contact your carrier to clear the status first."
    }
};

const flagNotes = {
    swollen: { danger: true, text: "A swollen battery is a fire risk. Stop charging the device and don't ship it yourself. Take it to a battery recycling drop-off. It can't be listed." },
    noPower: { text: "Because the device doesn't turn on, buyers will treat it as a repair or parts listing." },
    water: { text: "Water damage can cause problems later, like corrosion or camera fogging. It must be disclosed in your listing." },
    waterMaybe: { text: "If you suspect water exposure, say so in your listing so buyers know what to expect." },
    locked: { text: "A device locked to an account can't be set up by a new owner. Try recovering the account with the manufacturer first." },
    signedIn: { text: "Sign out of your accounts, turn off Find My or Google protection, and factory reset the device before you hand it over." },
    financed: { text: "A device that's still being paid off may be restricted by your carrier. Check with them before listing." },
    carrierLocked: { text: "A carrier-locked device can still sell. Name the carrier in your listing so buyers know." },
    bent: { text: "A bent frame can affect the buttons, cameras, wireless charging, and water resistance, even if the device powers on." },
    cracked: { text: "Take clear photos of the cracks, and remove any screen protector so buyers see the real glass." }
};

function buildResultHTML() {
    const { grade, flags, issues, percent, estimate } = diagnosticState.result;
    const info = gradeInfo[grade];
    const blocked = grade === "blocked";
    const canList = !blocked && !flags.has("swollen");

    const noteKeys = Object.keys(flagNotes).filter(key => flags.has(key));
    const dangerNotes = noteKeys.filter(key => flagNotes[key].danger);
    const otherNotes = noteKeys.filter(key => !flagNotes[key].danger);

    const notesHTML = (keys, extraClass) => keys.length ? `
        <div class="diag-notes ${extraClass}" role="note">
            <ul>${keys.map(key => `<li>${flagNotes[key].text}</li>`).join("")}</ul>
        </div>` : "";

    const priceHTML = blocked ? "" : estimate ? `
        <div class="diag-price">
            <div class="diag-price-label">Suggested price</div>
            <div class="diag-price-value">${formatPrice(estimate.suggested)}</div>
            <div class="diag-price-range">Typical range ${formatPrice(estimate.low)} to ${formatPrice(estimate.high)}</div>
            <p>Based on starting estimates for the ${escapeHTML(getLabel("model"))}, ${escapeHTML(getLabel("storage"))}, in ${info.label.toLowerCase()}.
               Check recent sold listings, and if you plan to fix it first, compare the repair cost to how much the fix would raise the price.</p>
        </div>` : `
        <div class="diag-price">
            <div class="diag-price-label">Suggested price</div>
            <p>We don't have a price for this model yet. Look up recent sold listings of the same model and storage, then price ${info.label.toLowerCase()} devices accordingly.</p>
        </div>`;

    const summaryHTML = diagnosticQuestions.map(question =>
        `<div><dt>${question.title.replace(/\?$/, "")}</dt><dd>${answerLabel(question)}</dd></div>`
    ).join("");

    return `
        <div class="diag-result">
            <span class="diag-grade ${info.css}">${info.label}${blocked ? "" : " · " + percent + "% score"}</span>
            <h2>${info.heading}</h2>
            <p>${info.text}</p>

            ${priceHTML}
            ${notesHTML(dangerNotes, "danger")}
            ${notesHTML(otherNotes, "")}

            <dl class="diag-summary">${summaryHTML}</dl>

            <div class="diag-actions">
                <button type="button" class="diag-secondary" onclick="startDiagnostic()">
                    Start over
                </button>
                ${canList ? `
                <button type="button" onclick="openListingForm()">
                    Create listing
                </button>` : `
                <button type="button" onclick="showPage('home-page')">
                    Back to Home
                </button>`}
            </div>
        </div>
    `;
}

/* ============================================
   CREATING A LISTING
   ============================================ */

const shortStorage = {
    "64 GB or less": "64 GB",
    "512 GB or more": "512 GB"
};

function buildTitle() {
    const model = getLabel("model");
    const storage = getLabel("storage");
    const name = model === OTHER_MODEL
        ? `${getLabel("brand")} ${getLabel("type")}`
        : model;
    const size = storage === "Not sure" ? "" : ", " + (shortStorage[storage] || storage);
    return name + size;
}

function buildDescription() {
    const { grade, issues } = diagnosticState.result;
    const lines = [gradeInfo[grade].label + ".", ""];

    if (issues.length) {
        lines.push("Known issues:");
        issues.forEach(issue => lines.push("- " + issue));
    } else {
        lines.push("No known issues. Everything works.");
    }

    lines.push("");
    lines.push("Carrier: " + getLabel("carrier"));
    lines.push("Included: " + getLabel("accessories"));
    return lines.join("\n");
}

function openListingForm() {
    const { estimate } = diagnosticState.result;

    diagnosticState.draft = {
        title: buildTitle(),
        price: estimate ? estimate.suggested : "",
        description: buildDescription(),
        photos: []
    };
    diagnosticState.view = "listing";
    renderDiagnostic();
    window.scrollTo({ top: 0, behavior: "smooth" });
}

function buildListingFormHTML() {
    const draft = diagnosticState.draft;
    const info = gradeInfo[diagnosticState.result.grade];

    return `
        <div class="diag-result" style="text-align: left;">
            <h2 style="text-align: center;">Create your listing</h2>
            <p style="text-align: center;">Check the details below. You can change anything before posting.</p>

            <div class="diag-field">
                <label for="listing-title">Title</label>
                <input type="text" id="listing-title" class="diag-text" maxlength="80"
                       value="${escapeHTML(draft.title)}"
                       oninput="diagnosticState.draft.title = this.value">
            </div>

            <div class="diag-field">
                <label for="listing-price">Price (USD)</label>
                <input type="number" id="listing-price" class="diag-text" min="1" step="1"
                       value="${escapeHTML(draft.price)}"
                       oninput="diagnosticState.draft.price = this.value">
            </div>

            <div class="diag-field">
                <label>Condition</label>
                <div><span class="diag-grade ${info.css}">${info.label}</span></div>
            </div>

            <div class="diag-field">
                <label for="listing-description">Description</label>
                <textarea id="listing-description" class="diag-text" rows="9"
                          oninput="diagnosticState.draft.description = this.value">${escapeHTML(draft.description)}</textarea>
            </div>

            <div class="diag-field">
                <label for="listing-photos">Photos (up to 4)</label>
                <input type="file" id="listing-photos" accept="image/*" multiple
                       onchange="addPhotos(this.files); this.value = ''">
                <div id="photo-preview" class="photo-preview"></div>
            </div>

            <div id="listing-error" class="diag-error" role="alert"></div>

            <div class="diag-actions">
                <button type="button" class="diag-secondary"
                        onclick="diagnosticState.view = 'result'; renderDiagnostic();">
                    Back to results
                </button>
                <button type="button" onclick="postListing()">Post listing</button>
            </div>
        </div>
    `;
}

// Shrinks each photo so a few of them fit in browser storage
function addPhotos(fileList) {
    const draft = diagnosticState.draft;
    const files = Array.from(fileList).slice(0, 4 - draft.photos.length);

    files.forEach(file => {
        if (!file.type.startsWith("image/")) return;

        const reader = new FileReader();
        reader.onload = () => {
            const img = new Image();
            img.onload = () => {
                const scale = Math.min(1, 800 / Math.max(img.width, img.height));
                const canvas = document.createElement("canvas");
                canvas.width = Math.round(img.width * scale);
                canvas.height = Math.round(img.height * scale);
                canvas.getContext("2d").drawImage(img, 0, 0, canvas.width, canvas.height);

                if (draft.photos.length < 4) {
                    draft.photos.push(canvas.toDataURL("image/jpeg", 0.7));
                }
                renderPhotoPreview();
            };
            img.src = reader.result;
        };
        reader.readAsDataURL(file);
    });
}

function removePhoto(index) {
    diagnosticState.draft.photos.splice(index, 1);
    renderPhotoPreview();
}

function renderPhotoPreview() {
    const box = document.getElementById("photo-preview");
    if (!box || !diagnosticState.draft) return;

    box.innerHTML = diagnosticState.draft.photos.map((src, index) => `
        <div class="photo-thumb">
            <img src="${src}" alt="Photo ${index + 1}">
            <button type="button" aria-label="Remove photo ${index + 1}"
                    onclick="removePhoto(${index})">×</button>
        </div>`).join("");
}

function postListing() {
    const draft = diagnosticState.draft;
    const error = document.getElementById("listing-error");
    const price = Number(draft.price);

    if (!draft.title.trim()) {
        error.textContent = "Add a title for your listing.";
        return;
    }
    if (!(price > 0)) {
        error.textContent = "Enter a price above $0.";
        return;
    }

    const { grade, issues } = diagnosticState.result;

    const listing = {
        id: String(Date.now()),
        title: draft.title.trim(),
        price: Math.round(price),
        description: draft.description.trim(),
        photos: draft.photos,
        type: getLabel("type"),
        brand: getLabel("brand"),
        model: getLabel("model"),
        storage: getLabel("storage"),
        grade,
        issues,
        status: "active",
        createdAt: new Date().toISOString()
    };

    try {
        const list = loadListings();
        list.unshift(listing);
        saveListings(list);
    } catch (e) {
        error.textContent = "Couldn't save the listing. Try removing a photo.";
        return;
    }

    diagnosticState.view = "posted";
    renderDiagnostic();
    window.scrollTo({ top: 0, behavior: "smooth" });
}

function buildPostedHTML() {
    return `
        <div class="coming-soon-content">
            <span class="coming-soon-icon">🎉</span>
            <h2>Your listing is live</h2>
            <p>Buyers can now find it in search and under ${getLabel("type") === "Tablet" ? "Tablets" : "Phones"}.</p>
            <div class="diag-actions">
                <button type="button" class="diag-secondary" onclick="showPage('sell-page')">
                    Sell another device
                </button>
                <button type="button" onclick="showPage('listings-page')">
                    View my listings
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
