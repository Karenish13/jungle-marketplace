
/* JUNGLE MARKETPLACE */

// Buyer features only
const comingSoonPages = {
    "explore-page": ["Find Parts", "Browse replacement parts for phones and tablets."],
    "listings-page": ["My Listings", "Manage your device listings here."],
    "profile-page": ["Profile", "Account features are under development."],
    "search-page": ["Marketplace Search", "Search for devices and parts."],
    "phones-page": ["Phones", "Browse phones and parts."],
    "tablets-page": ["Tablets", "Browse tablets and parts."]
};

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
        options: ["64 GB", "128 GB", "256 GB", "512 GB or more", "Not sure"]
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
        options: ["Works", "Has problems", "Does not work", "Not tested"]
    },
    {
        key: "frontCamera",
        question: "Does the front camera work?",
        options: ["Works", "Has problems", "Does not work", "Not tested"]
    },
    {
        key: "speakers",
        question: "Do the speakers work?",
        options: ["Clear sound", "Distorted or quiet", "No sound", "Not tested"]
    },
    {
        key: "microphone",
        question: "Does the microphone work?",
        options: ["Works", "Muffled or distorted", "Does not work", "Not tested"]
    },
    {
        key: "wifi",
        question: "Does Wi-Fi work?",
        options: ["Yes", "Unreliable", "No", "Not tested"]
    },
    {
        key: "bluetooth",
        question: "Does Bluetooth work?",
        options: ["Yes", "Unreliable", "No", "Not tested"]
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
        options: ["Yes", "Need help", "Unsure", "No"]
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

let sellerAnswers = {};
let currentQuestion = 0;
let showingEstimate = false;

// Navigation

function hideAllPages() {
    document.getElementById("home-page").hidden = true;
    document.getElementById("seller-page").hidden = true;
    document.getElementById("coming-soon-page").hidden = true;
}

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

function showPage(pageId) {
    if (pageId === "home-page") {
        hideAllPages();
        document.getElementById("home-page").hidden = false;
        window.scrollTo(0, 0);
        return;
    }

    if (pageId === "sell-page") {
        openSeller();
        return;
    }

    const page = comingSoonPages[pageId];

    if (!page) {
        showPage("home-page");
        return;
    }

    hideAllPages();

    document.getElementById("coming-soon-title").textContent = page[0];
    document.getElementById("coming-soon-message").textContent = page[1];
    document.getElementById("coming-soon-page").hidden = false;

    window.scrollTo(0, 0);
}

function searchMarketplace() {
    showPage("search-page");
}

function filterCategory(category) {
    showPage(category === "Phones" ? "phones-page" : "tablets-page");
}

// Question display

function showSellerQuestion() {
    showingEstimate = false;

    const question = sellerQuestions[currentQuestion];
    const container = document.getElementById("seller-questionnaire");

    container.replaceChildren();

    const progress = document.createElement("p");
    progress.className = "question-progress";
    progress.textContent =
        `Question ${currentQuestion + 1} of ${sellerQuestions.length}`;

    const track = document.createElement("div");
    track.className = "progress-track";

    const fill = document.createElement("div");
    fill.className = "progress-fill";
    fill.style.width =
        `${((currentQuestion + 1) / sellerQuestions.length) * 100}%`;

    track.appendChild(fill);

    const title = document.createElement("h3");
    title.className = "question-title";
    title.textContent = question.question;

    container.append(progress, track, title);

    const optionsContainer = document.createElement("div");
    optionsContainer.className = "seller-options";

    if (question.text) {
        const textarea = document.createElement("textarea");
        textarea.className = "seller-textarea";
        textarea.placeholder = "Your answer (optional)";
        textarea.value = sellerAnswers[question.key] || "";

        textarea.addEventListener("input", () => {
            sellerAnswers[question.key] = textarea.value;
        });

        optionsContainer.appendChild(textarea);
    } else {
        const options =
            typeof question.options === "function"
                ? question.options()
                : question.options;

        options.forEach(option => {
            const label = document.createElement("label");
            label.className = "seller-option";

            const radio = document.createElement("input");
            radio.type = "radio";
            radio.name = "seller-answer";
            radio.value = option;
            radio.checked = sellerAnswers[question.key] === option;

            radio.addEventListener("change", () => {
                if (
                    question.key === "type" &&
                    sellerAnswers.type !== option
                ) {
                    delete sellerAnswers.model;
                    delete sellerAnswers.customModel;
                }

                sellerAnswers[question.key] = option;

                if (question.key === "model") {
                    if (option !== "Other model") {
                        delete sellerAnswers.customModel;
                    }
                    showSellerQuestion();
                }
            });

            const text = document.createElement("span");
            text.textContent = option;

            label.append(radio, text);
            optionsContainer.appendChild(label);
        });

        if (
            question.key === "model" &&
            sellerAnswers.model === "Other model"
        ) {
            const customInput = document.createElement("input");
            customInput.type = "text";
            customInput.className = "seller-text-input";
            customInput.placeholder = "Enter your device model";
            customInput.value = sellerAnswers.customModel || "";

            customInput.addEventListener("input", () => {
                sellerAnswers.customModel = customInput.value;
            });

            optionsContainer.appendChild(customInput);
        }
    }

    container.appendChild(optionsContainer);

    const error = document.createElement("p");
    error.className = "seller-error";
    error.setAttribute("role", "alert");
    container.appendChild(error);

    const navigation = document.createElement("div");
    navigation.className = "seller-navigation";

    const backButton = document.createElement("button");
    backButton.type = "button";
    backButton.className = "seller-secondary";
    backButton.textContent = "Back";
    backButton.disabled = currentQuestion === 0;

    backButton.addEventListener("click", () => {
        if (currentQuestion > 0) {
            currentQuestion--;
            showSellerQuestion();
        }
    });

    const nextButton = document.createElement("button");
    nextButton.type = "button";
    nextButton.textContent =
        currentQuestion === sellerQuestions.length - 1
            ? "View Price Estimate"
            : "Next";

    nextButton.addEventListener("click", () => {
        if (
            !question.optional &&
            !sellerAnswers[question.key]
        ) {
            error.textContent = "Please select an answer.";
            return;
        }

        if (
            question.key === "model" &&
            sellerAnswers.model === "Other model" &&
            !sellerAnswers.customModel?.trim()
        ) {
            error.textContent = "Please enter the device model.";
            return;
        }

        if (currentQuestion === sellerQuestions.length - 1) {
            showPriceEstimate();
        } else {
            currentQuestion++;
            showSellerQuestion();
        }
    });

    navigation.append(backButton, nextButton);
    container.appendChild(navigation);
}

// Demonstration price estimate

function calculateEstimate() {
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

    Object.entries(adjustments).forEach(([key, values]) => {
        price += values[sellerAnswers[key]] || 0;
    });

    if (sellerAnswers.accessories === "Original box and charger") {
        price += 10;
    }

    const estimate = Math.max(
        10,
        Math.round(price / 5) * 5
    );

    return { basePrice, estimate };
}

function showPriceEstimate() {
    showingEstimate = true;

    const container = document.getElementById("seller-questionnaire");
    container.replaceChildren();

    const result = calculateEstimate();

    const modelName =
        sellerAnswers.model === "Other model"
            ? sellerAnswers.customModel
            : sellerAnswers.model;

    const card = document.createElement("div");
    card.className = "estimate-card";

    const heading = document.createElement("h3");
    heading.className = "question-title";
    heading.textContent = "Your Estimated Device Value";

    const model = document.createElement("p");
    model.className = "estimate-model";
    model.textContent = modelName;

    const price = document.createElement("div");
    price.className = "estimated-price";
    price.textContent = `$${result.estimate}`;

    const note = document.createElement("p");
    note.className = "seller-note";
    note.textContent =
        "This is a demonstration estimate based on seller-reported " +
        "answers, not a verified diagnostic or live market appraisal. " +
        "Damaged devices may still contain reusable parts. " +
        "Activation locks must be resolved before a future sale.";

    card.append(heading, model, price, note);
    container.appendChild(card);

    const navigation = document.createElement("div");
    navigation.className = "seller-navigation";

    const reviewButton = document.createElement("button");
    reviewButton.type = "button";
    reviewButton.textContent = "Review Answers";
    reviewButton.className = "seller-secondary";
    reviewButton.addEventListener("click", () => {
        currentQuestion = sellerQuestions.length - 1;
        showSellerQuestion();
    });

    const restartButton = document.createElement("button");
    restartButton.type = "button";
    restartButton.textContent = "Start Over";
    restartButton.addEventListener("click", () => {
        sellerAnswers = {};
        currentQuestion = 0;
        showSellerQuestion();
    });

    const homeButton = document.createElement("button");
    homeButton.type = "button";
    homeButton.textContent = "Back to Home";
    homeButton.className = "seller-secondary";
    homeButton.addEventListener("click", () => {
        showPage("home-page");
    });

    navigation.append(reviewButton, restartButton, homeButton);
    container.appendChild(navigation);
}

// Initialize

document.addEventListener("DOMContentLoaded", () => {
    const searchInput = document.getElementById("marketplace-search");

    if (searchInput) {
        searchInput.addEventListener("keydown", event => {
            if (event.key === "Enter") {
                searchMarketplace();
            }
        });
    }

    showPage("home-page");
});
