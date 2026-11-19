
/* JUNGLE MARKETPLACE */
/* SELL A DEVICE QUESTIONNAIRE */

// ========================================
// COMING SOON PAGES
// ========================================

// Sell a Device is intentionally NOT here.
const comingSoonPages = {
    "explore-page": {
        title: "Find Parts",
        message: "Coming Soon! Browse replacement parts for phones and tablets."
    },

    "listings-page": {
        title: "My Listings",
        message: "Coming Soon! Manage your device listings here."
    },

    "profile-page": {
        title: "Profile",
        message: "Coming Soon! Account features are under development."
    },

    "search-page": {
        title: "Marketplace Search",
        message: "Coming Soon! Search for devices and replacement parts."
    },

    "phones-page": {
        title: "Phones",
        message: "Coming Soon! Browse phones and replacement parts."
    },

    "tablets-page": {
        title: "Tablets",
        message: "Coming Soon! Browse tablets and replacement parts."
    }
};

// ========================================
// DEVICE MODELS
// ========================================

const deviceModels = {
    Phone: [
        "iPhone 13",
        "iPhone 14",
        "Samsung Galaxy S22",
        "Google Pixel 7",
        "Other model"
    ],

    Tablet: [
        "iPad 9th Generation",
        "iPad 10th Generation",
        "iPad Air",
        "Samsung Galaxy Tab S8",
        "Other model"
    ]
};

// ========================================
// SELLER QUESTIONS
// ========================================

const sellerQuestions = [
    {
        key: "type",
        question: "What kind of device are you selling?",
        options: ["Phone", "Tablet"]
    },

    {
        key: "model",
        question: "What model is your device?",
        options: () => deviceModels[sellerAnswers.type] || []
    },

    {
        key: "storage",
        question: "How much storage does it have?",
        options: [
            "64 GB",
            "128 GB",
            "256 GB",
            "512 GB or more",
            "Not sure"
        ]
    },

    {
        key: "exterior",
        question: "What is the exterior condition?",
        options: [
            "Like new",
            "Minor scratches",
            "Cracked glass or noticeable damage",
            "Bent or severely damaged"
        ]
    },

    {
        key: "screen",
        question: "Does the screen work?",
        options: [
            "Works perfectly",
            "Cracked but works",
            "Display problems",
            "Touchscreen problems",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "battery",
        question: "What is the battery health?",
        options: [
            "90% or higher",
            "80% to 89%",
            "Below 80%",
            "Battery does not work",
            "Unknown"
        ]
    },

    {
        key: "charging",
        question: "Does the device charge normally?",
        options: [
            "Yes",
            "Slow or inconsistent",
            "Does not charge",
            "Not tested"
        ]
    },

    {
        key: "rearCamera",
        question: "Does the rear camera work?",
        options: [
            "Works",
            "Has problems",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "frontCamera",
        question: "Does the front camera work?",
        options: [
            "Works",
            "Has problems",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "speakers",
        question: "Do the speakers work?",
        options: [
            "Clear sound",
            "Distorted or quiet",
            "No sound",
            "Not tested"
        ]
    },

    {
        key: "microphone",
        question: "Does the microphone work?",
        options: [
            "Works",
            "Muffled or distorted",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "wifi",
        question: "Does Wi-Fi work?",
        options: [
            "Yes",
            "Unreliable",
            "No",
            "Not tested"
        ]
    },

    {
        key: "bluetooth",
        question: "Does Bluetooth work?",
        options: [
            "Yes",
            "Unreliable",
            "No",
            "Not tested"
        ]
    },

    {
        key: "cellular",
        question: "Does cellular service work, if supported?",
        options: [
            "Yes",
            "Some problems",
            "No",
            "Wi-Fi-only device / Not applicable",
            "Not tested"
        ]
    },

    {
        key: "water",
        question: "Has the device been exposed to water?",
        options: [
            "No",
            "Yes, but still works",
            "Yes, and has problems",
            "Unsure"
        ]
    },

    {
        key: "repairs",
        question: "Has the device been repaired?",
        options: [
            "No",
            "Screen replacement",
            "Battery replacement",
            "Other repair",
            "Unsure"
        ]
    },

    {
        key: "power",
        question: "Does the device turn on?",
        options: [
            "Fully functional",
            "Turns on with some issues",
            "Does not turn on",
            "Turns on but cannot be used normally"
        ]
    },

    {
        key: "locks",
        question: "Can you remove your accounts and activation locks?",
        options: [
            "Yes",
            "Need help",
            "Unsure",
            "No"
        ]
    },

    {
        key: "accessories",
        question: "What accessories are included?",
        options: [
            "Original box and charger",
            "Charger only",
            "Device only",
            "Other accessories"
        ]
    },

    {
        key: "reason",
        question: "Why are you selling your device?",
        optional: true,
        text: true
    }
];

// ========================================
// QUESTIONNAIRE STATE
// ========================================

let sellerAnswers = {};
let currentQuestion = 0;
let showingEstimate = false;

// ========================================
// HTML ELEMENT HELPER
// ========================================

function createElement(tag, className, text) {
    const element = document.createElement(tag);

    if (className) {
        element.className = className;
    }

    if (text !== undefined) {
        element.textContent = text;
    }

    return element;
}

// ========================================
// HIDE ALL PAGES
// ========================================

function hideAllPages() {
    document.getElementById("home-page").hidden = true;
    document.getElementById("seller-page").hidden = true;
    document.getElementById("coming-soon-page").hidden = true;
}

// ========================================
// OPEN SELLER QUESTIONNAIRE
// ========================================

function openSeller() {
    hideAllPages();

    document.getElementById("seller-page").hidden = false;

    if (showingEstimate) {
        showPriceEstimate();
    } else {
        showSellerQuestion();
    }

    window.scrollTo(0, 0);
}

// ========================================
// PAGE NAVIGATION
// ========================================

function showPage(pageId) {

    // Home page
    if (pageId === "home-page") {
        hideAllPages();

        document.getElementById("home-page").hidden = false;

        window.scrollTo(0, 0);
        return;
    }

    // Always route Sell directly to questionnaire
    if (pageId === "sell-page") {
        openSeller();
        return;
    }

    // Only buyer and unfinished pages
    const page = comingSoonPages[pageId];

    if (!page) {
        showPage("home-page");
        return;
    }

    hideAllPages();

    document.getElementById(
        "coming-soon-title"
    ).textContent = page.title;

    document.getElementById(
        "coming-soon-message"
    ).textContent = page.message;

    document.getElementById(
        "coming-soon-page"
    ).hidden = false;

    window.scrollTo(0, 0);
}

// ========================================
// SEARCH AND CATEGORIES
// ========================================

function searchMarketplace() {
    showPage("search-page");
}

function filterCategory(category) {
    if (category === "Phones") {
        showPage("phones-page");
    } else if (category === "Tablets") {
        showPage("tablets-page");
    }
}

// ========================================
// DISPLAY ONE QUESTION
// ========================================

function showSellerQuestion() {
    showingEstimate = false;

    const question = sellerQuestions[currentQuestion];

    const container = document.getElementById(
        "seller-questionnaire"
    );

    container.replaceChildren();

    // Progress text
    const progressText = createElement(
        "p",
        "question-progress",
        `Question ${currentQuestion + 1} of ${sellerQuestions.length}`
    );

    // Progress bar
    const progressTrack = createElement(
        "div",
        "progress-track"
    );

    const progressFill = createElement(
        "div",
        "progress-fill"
    );

    progressFill.style.width =
        `${((currentQuestion + 1) / sellerQuestions.length) * 100}%`;

    progressTrack.appendChild(progressFill);

    // Question title
    const title = createElement(
        "h3",
        "question-title",
        question.question
    );

    container.append(
        progressText,
        progressTrack,
        title
    );

    // Answer container
    const optionsContainer = createElement(
        "div",
        "seller-options"
    );

    // Optional written question
    if (question.text) {
        const textarea = createElement(
            "textarea",
            "seller-textarea"
        );

        textarea.placeholder =
            "Tell us more about your device (optional)";

        textarea.value =
            sellerAnswers[question.key] || "";

        textarea.addEventListener("input", () => {
            sellerAnswers[question.key] = textarea.value;
        });

        optionsContainer.appendChild(textarea);
    }

    // Multiple choice questions
    else {
        const options =
            typeof question.options === "function"
                ? question.options()
                : question.options;

        options.forEach(option => {
            const label = createElement(
                "label",
                "seller-option"
            );

            const radio = document.createElement("input");

            radio.type = "radio";
            radio.name = "seller-answer";
            radio.value = option;

            radio.checked =
                sellerAnswers[question.key] === option;

            radio.addEventListener("change", () => {

                // Clear model if device type changes
                if (
                    question.key === "type" &&
                    sellerAnswers.type !== option
                ) {
                    delete sellerAnswers.model;
                    delete sellerAnswers.customModel;
                }

                sellerAnswers[question.key] = option;

                // Refresh custom model field
                if (question.key === "model") {
                    if (option !== "Other model") {
                        delete sellerAnswers.customModel;
                    }

                    showSellerQuestion();
                }
            });

            const labelText = createElement(
                "span",
                "",
                option
            );

            label.append(radio, labelText);
            optionsContainer.appendChild(label);
        });

        // Custom model input
        if (
            question.key === "model" &&
            sellerAnswers.model === "Other model"
        ) {
            const customContainer = createElement(
                "div",
                "custom-model"
            );

            const customLabel = createElement(
                "label",
                "",
                "Enter your device model"
            );

            const customInput = createElement(
                "input",
                "seller-text-input"
            );

            customInput.type = "text";
            customInput.placeholder =
                "Example: iPhone 12 Pro or iPad Air 5";

            customInput.value =
                sellerAnswers.customModel || "";

            customInput.addEventListener("input", () => {
                sellerAnswers.customModel = customInput.value;
            });

            customContainer.append(
                customLabel,
                customInput
            );

            optionsContainer.appendChild(customContainer);
        }
    }

    container.appendChild(optionsContainer);

    // Validation error
    const errorMessage = createElement(
        "p",
        "seller-error"
    );

    errorMessage.setAttribute("role", "alert");

    container.appendChild(errorMessage);

    // Navigation buttons
    const navigation = createElement(
        "div",
        "seller-navigation"
    );

    // Back button
    const backButton = createElement(
        "button",
        "seller-secondary",
        "Back"
    );

    backButton.type = "button";
    backButton.disabled = currentQuestion === 0;

    backButton.addEventListener("click", () => {
        if (currentQuestion > 0) {
            currentQuestion--;
            showSellerQuestion();
        }
    });

    // Next button
    const nextButton = createElement(
        "button",
        "",
        currentQuestion === sellerQuestions.length - 1
            ? "View Price Estimate"
            : "Next"
    );

    nextButton.type = "button";

    nextButton.addEventListener("click", () => {

        // Require answer for multiple choice
        if (
            !question.optional &&
            !sellerAnswers[question.key]
        ) {
            errorMessage.textContent =
                "Please select an answer before continuing.";
            return;
        }

        // Require custom model name
        if (
            question.key === "model" &&
            sellerAnswers.model === "Other model" &&
            !sellerAnswers.customModel?.trim()
        ) {
            errorMessage.textContent =
                "Please enter the model of your device.";
            return;
        }

        // Final question
        if (
            currentQuestion ===
            sellerQuestions.length - 1
        ) {
            showPriceEstimate();
        }

        // Next question
        else {
            currentQuestion++;
            showSellerQuestion();
        }
    });

    navigation.append(
        backButton,
        nextButton
    );

    container.appendChild(navigation);
}

// ========================================
// PRICE ESTIMATE
// ========================================

function calculateEstimate() {

    // Demonstration model values only
    const basePrices = {
        "iPhone 13": 180,
        "iPhone 14": 240,
        "Samsung Galaxy S22": 175,
        "Google Pixel 7": 150,
        "iPad 9th Generation": 150,
        "iPad 10th Generation": 210,
        "iPad Air": 220,
        "Samsung Galaxy Tab S8": 200
    };

    const basePrice =
        basePrices[sellerAnswers.model] ||
        (sellerAnswers.type === "Tablet" ? 130 : 120);

    let price = basePrice;

    // Condition adjustments
    const adjustments = {

        storage: {
            "64 GB": -15,
            "256 GB": 20,
            "512 GB or more": 40,
            "Not sure": -10
        },

        exterior: {
            "Minor scratches": -10,
            "Cracked glass or noticeable damage": -25,
            "Bent or severely damaged": -65
        },

        screen: {
            "Cracked but works": -35,
            "Display problems": -55,
            "Touchscreen problems": -55,
            "Does not work": -80,
            "Not tested": -20
        },

        battery: {
            "80% to 89%": -10,
            "Below 80%": -25,
            "Battery does not work": -50,
            "Unknown": -10
        },

        charging: {
            "Slow or inconsistent": -20,
            "Does not charge": -45,
            "Not tested": -10
        },

        rearCamera: {
            "Has problems": -15,
            "Does not work": -35,
            "Not tested": -8
        },

        frontCamera: {
            "Has problems": -15,
            "Does not work": -30,
            "Not tested": -8
        },

        speakers: {
            "Distorted or quiet": -15,
            "No sound": -25,
            "Not tested": -8
        },

        microphone: {
            "Muffled or distorted": -15,
            "Does not work": -25,
            "Not tested": -8
        },

        wifi: {
            "Unreliable": -15,
            "No": -35,
            "Not tested": -8
        },

        bluetooth: {
            "Unreliable": -10,
            "No": -20,
            "Not tested": -5
        },

        cellular: {
            "Some problems": -20,
            "No": -40,
            "Not tested": -10
        },

        water: {
            "Yes, but still works": -20,
            "Yes, and has problems": -60,
            "Unsure": -10
        },

        power: {
            "Turns on with some issues": -25,
            "Does not turn on": -90,
            "Turns on but cannot be used normally": -60
        }
    };

    // Apply each condition adjustment
    Object.entries(adjustments).forEach(
        ([key, values]) => {
            price += values[sellerAnswers[key]] || 0;
        }
    );

    // Accessories
    if (
        sellerAnswers.accessories ===
        "Original box and charger"
    ) {
        price += 10;
    }

    // Demo minimum, not guaranteed resale value
    const estimate = Math.max(
        10,
        Math.round(price / 5) * 5
    );

    return {
        basePrice,
        estimate,
        adjustmentTotal: estimate - basePrice
    };
}

// ========================================
// DISPLAY PRICE ESTIMATE
// ========================================

function showPriceEstimate() {
    showingEstimate = true;

    const container = document.getElementById(
        "seller-questionnaire"
    );

    container.replaceChildren();

    const result = calculateEstimate();

    const modelName =
        sellerAnswers.model === "Other model"
            ? sellerAnswers.customModel
            : sellerAnswers.model;

    const card = createElement(
        "div",
        "estimate-card"
    );

    const heading = createElement(
        "h3",
        "question-title",
        "Your Estimated Device Value"
    );

    const model = createElement(
        "p",
        "estimate-model",
        modelName
    );

    const price = createElement(
        "div",
        "estimated-price",
        `$${result.estimate}`
    );

    const breakdown = createElement(
        "div",
        "estimate-breakdown"
    );

    const startingValue = createElement(
        "p",
        "",
        `Illustrative starting value: $${result.basePrice}`
    );

    const adjustment = createElement(
        "p",
        "",
        `Condition and storage adjustments: ` +
        `${result.adjustmentTotal < 0 ? "-" : "+"}` +
        `$${Math.abs(result.adjustmentTotal)}`
    );

    const finalValue = createElement(
        "p",
        "",
        `Estimated value: $${result.estimate}`
    );

    breakdown.append(
        startingValue,
        adjustment,
        finalValue
    );

    const note = createElement(
        "p",
        "seller-note",
        "This is a demonstration estimate based on " +
        "seller-reported answers, not a live appraisal " +
        "or verified diagnostic report. Damaged devices " +
        "may still contain reusable parts. Account locks " +
        "must be resolved before a future sale."
    );

    card.append(
        heading,
        model,
        price,
        breakdown,
        note
    );

    container.appendChild(card);

    // Buttons
    const navigation = createElement(
        "div",
        "seller-navigation"
    );

    // Review answers
    const reviewButton = createElement(
        "button",
        "seller-secondary",
        "Review Answers"
    );

    reviewButton.type = "button";

    reviewButton.addEventListener("click", () => {
        currentQuestion = sellerQuestions.length - 1;
        showSellerQuestion();
    });

    // Start over
    const restartButton = createElement(
        "button",
        "",
        "Start Over"
    );

    restartButton.type = "button";

    restartButton.addEventListener("click", () => {
        sellerAnswers = {};
        currentQuestion = 0;
        showSellerQuestion();
    });

    // Home
    const homeButton = createElement(
        "button",
        "seller-secondary",
        "Back to Home"
    );

    homeButton.type = "button";

    homeButton.addEventListener("click", () => {
        showPage("home-page");
    });

    navigation.append(
        reviewButton,
        restartButton,
        homeButton
    );

    container.appendChild(navigation);
}

// ========================================
// INITIALIZE WEBSITE
// ========================================

document.addEventListener("DOMContentLoaded", () => {

    const searchInput = document.getElementById(
        "marketplace-search"
    );

    if (searchInput) {
        searchInput.addEventListener("keydown", event => {
            if (event.key === "Enter") {
                searchMarketplace();
            }
        });
    }

    showPage("home-page");
});
