
/* JUNGLE MARKETPLACE */
/* Seller questionnaire demonstration */

// Pages that are still under development
const pages = {
    "explore-page": [
        "Find Parts",
        "Coming Soon! Replacement parts browsing is under development."
    ],

    "listings-page": [
        "My Listings",
        "Coming Soon! Listings are not available yet."
    ],

    "profile-page": [
        "Profile",
        "Coming Soon! Accounts are not available yet."
    ],

    "search-page": [
        "Marketplace Search",
        "Coming Soon! Search is not available yet."
    ],

    "phones-page": [
        "Phones",
        "Coming Soon! Phone listings are not available yet."
    ],

    "tablets-page": [
        "Tablets",
        "Coming Soon! Tablet listings are not available yet."
    ]
};

// Available demonstration models
const models = {
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

// SELLER QUESTIONS
const questions = [
    {
        key: "type",
        title: "What kind of device are you selling?",
        options: ["Phone", "Tablet"]
    },

    {
        key: "model",
        title: "What model is your device?",
        options: () => models[answers.type] || []
    },

    {
        key: "storage",
        title: "How much storage does it have?",
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
        title: "What is the exterior condition?",
        options: [
            "Like new",
            "Minor scratches",
            "Cracked glass or noticeable damage",
            "Bent or severely damaged"
        ]
    },

    {
        key: "screen",
        title: "Does the screen work?",
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
        title: "What is the battery health?",
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
        title: "Does the device charge normally?",
        options: [
            "Yes",
            "Slow or inconsistent",
            "Does not charge",
            "Not tested"
        ]
    },

    {
        key: "rearCamera",
        title: "Does the rear camera work?",
        options: [
            "Works",
            "Has problems",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "frontCamera",
        title: "Does the front camera work?",
        options: [
            "Works",
            "Has problems",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "speakers",
        title: "Do the speakers work?",
        options: [
            "Clear sound",
            "Distorted or quiet",
            "No sound",
            "Not tested"
        ]
    },

    {
        key: "microphone",
        title: "Does the microphone work?",
        options: [
            "Works",
            "Muffled or distorted",
            "Does not work",
            "Not tested"
        ]
    },

    {
        key: "wifi",
        title: "Does Wi-Fi work?",
        options: [
            "Yes",
            "Unreliable",
            "No",
            "Not tested"
        ]
    },

    {
        key: "bluetooth",
        title: "Does Bluetooth work?",
        options: [
            "Yes",
            "Unreliable",
            "No",
            "Not tested"
        ]
    },

    {
        key: "cellular",
        title: "Does cellular service work, if supported?",
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
        title: "Has it been exposed to water?",
        options: [
            "No",
            "Yes, but still works",
            "Yes, and has problems",
            "Unsure"
        ]
    },

    {
        key: "repairs",
        title: "Has it been repaired?",
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
        title: "Does the device turn on?",
        options: [
            "Fully functional",
            "Turns on with some issues",
            "Does not turn on",
            "Turns on but cannot be used normally"
        ]
    },

    {
        key: "locks",
        title: "Can you remove your accounts and activation locks?",
        options: [
            "Yes",
            "Need help",
            "Unsure",
            "No"
        ]
    },

    {
        key: "accessories",
        title: "What accessories are included?",
        options: [
            "Original box and charger",
            "Charger only",
            "Device only",
            "Other accessories"
        ]
    },

    {
        key: "reason",
        title: "Why are you selling your device? (Optional)",
        text: true
    }
];

// QUESTIONNAIRE STATE
let answers = {};
let step = 0;
let estimateVisible = false;

// Helper to create HTML elements safely
const el = (tag, className, content) => {
    const node = document.createElement(tag);

    if (className) {
        node.className = className;
    }

    if (content !== undefined) {
        node.textContent = content;
    }

    return node;
};

// PAGE NAVIGATION
function showPage(pageId) {
    const home = document.getElementById("home-page");
    const seller = document.getElementById("seller-page");
    const placeholder = document.getElementById("coming-soon-page");

    // Hide all pages
    home.hidden = true;
    seller.hidden = true;
    placeholder.hidden = true;

    // HOME
    if (pageId === "home-page") {
        home.hidden = false;
    }

    // SELL A DEVICE
    else if (pageId === "sell-page") {
        seller.hidden = false;

        if (estimateVisible) {
            showPriceEstimate();
        } else {
            showSellerQuestion();
        }
    }

    // COMING SOON FEATURES
    else {
        const [title, message] = pages[pageId] || [
            "Coming Soon",
            "This feature is under development."
        ];

        document.getElementById(
            "coming-soon-title"
        ).textContent = title;

        document.getElementById(
            "coming-soon-message"
        ).textContent = message;

        placeholder.hidden = false;
    }

    window.scrollTo(0, 0);
}

// SEARCH PLACEHOLDER
function searchMarketplace() {
    showPage("search-page");
}

// CATEGORY PLACEHOLDERS
function filterCategory(category) {
    if (category === "Phones") {
        showPage("phones-page");
    } else {
        showPage("tablets-page");
    }
}

// DISPLAY QUESTIONNAIRE
function showSellerQuestion() {
    estimateVisible = false;

    const q = questions[step];

    const root = document.getElementById(
        "seller-questionnaire"
    );

    root.replaceChildren();

    // Question number
    root.append(
        el(
            "p",
            "question-progress",
            `Question ${step + 1} of ${questions.length}`
        )
    );

    // Progress bar
    const track = el("div", "progress-track");
    const fill = el("div", "progress-fill");

    fill.style.width =
        `${100 * (step + 1) / questions.length}%`;

    track.append(fill);

    root.append(
        track,
        el("h3", "", q.title)
    );

    // Answer options
    const options = el("div", "seller-options");

    // Optional written response
    if (q.text) {
        const input = el(
            "textarea",
            "seller-textarea"
        );

        input.placeholder = "Tell us more (optional)";
        input.value = answers[q.key] || "";

        input.addEventListener("input", () => {
            answers[q.key] = input.value;
        });

        options.append(input);
    }

    // Multiple choice questions
    else {
        const choices =
            typeof q.options === "function"
                ? q.options()
                : q.options;

        choices.forEach(choice => {
            const label = el(
                "label",
                "seller-option"
            );

            const radio = document.createElement("input");

            radio.type = "radio";
            radio.name = "seller-answer";
            radio.value = choice;

            radio.checked =
                answers[q.key] === choice;

            radio.addEventListener("change", () => {

                // Reset model when device type changes
                if (
                    q.key === "type" &&
                    answers.type !== choice
                ) {
                    delete answers.model;
                    delete answers.customModel;
                }

                answers[q.key] = choice;

                // Refresh model field when selected
                if (q.key === "model") {
                    showSellerQuestion();
                }
            });

            label.append(
                radio,
                el("span", "", choice)
            );

            options.append(label);
        });

        // Custom device model
        if (
            q.key === "model" &&
            answers.model === "Other model"
        ) {
            const input = el(
                "input",
                "seller-textarea"
            );

            input.type = "text";
            input.placeholder = "Enter the model name";
            input.value = answers.customModel || "";

            input.addEventListener("input", () => {
                answers.customModel = input.value;
            });

            options.append(input);
        }
    }

    root.append(options);

    // Validation message
    const error = el("p", "seller-error");
    error.setAttribute("role", "alert");

    root.append(error);

    // Navigation buttons
    const navigation = el(
        "div",
        "seller-navigation"
    );

    // BACK BUTTON
    const back = el(
        "button",
        "seller-secondary",
        "Back"
    );

    back.type = "button";
    back.disabled = step === 0;

    back.addEventListener("click", () => {
        step--;
        showSellerQuestion();
    });

    // NEXT BUTTON
    const next = el(
        "button",
        "",
        step === questions.length - 1
            ? "View Price Estimate"
            : "Next"
    );

    next.type = "button";

    next.addEventListener("click", () => {

        // Require an answer except for optional text
        if (!q.text && !answers[q.key]) {
            error.textContent =
                "Please select an answer.";
            return;
        }

        // Require model name for Other model
        if (
            q.key === "model" &&
            answers.model === "Other model" &&
            !answers.customModel?.trim()
        ) {
            error.textContent =
                "Please enter the model name.";
            return;
        }

        // Final question
        if (step === questions.length - 1) {
            showPriceEstimate();
        }

        // Continue questionnaire
        else {
            step++;
            showSellerQuestion();
        }
    });

    navigation.append(back, next);
    root.append(navigation);
}

// PRICE ESTIMATE CALCULATION
function calculateEstimate() {

    // Illustrative starting values
    const bases = {
        "iPhone 13": 180,
        "iPhone 14": 240,
        "Samsung Galaxy S22": 175,
        "Google Pixel 7": 150,
        "iPad 9th Generation": 150,
        "iPad 10th Generation": 210,
        "iPad Air": 220,
        "Samsung Galaxy Tab S8": 200
    };

    const base =
        bases[answers.model] ||
        (answers.type === "Tablet" ? 130 : 120);

    let price = base;

    // Condition adjustments
    const penalties = {

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

    // Apply adjustments
    Object.entries(penalties).forEach(
        ([key, values]) => {
            price += values[answers[key]] || 0;
        }
    );

    // Accessories adjustment
    if (
        answers.accessories ===
        "Original box and charger"
    ) {
        price += 10;
    }

    // Demo-only estimate
    const estimate = Math.max(
        10,
        Math.round(price / 5) * 5
    );

    return {
        base,
        estimate
    };
}

// DISPLAY FINAL PRICE ESTIMATE
function showPriceEstimate() {
    estimateVisible = true;

    const root = document.getElementById(
        "seller-questionnaire"
    );

    root.replaceChildren();

    const { base, estimate } = calculateEstimate();

    // Title
    root.append(
        el(
            "h3",
            "",
            "Your Estimated Device Value"
        )
    );

    // Model name
    const modelName =
        answers.model === "Other model"
            ? answers.customModel
            : answers.model;

    root.append(
        el("p", "", modelName)
    );

    // Price
    root.append(
        el(
            "div",
            "estimated-price",
            `$${estimate}`
        )
    );

    // Explanation
    root.append(
        el(
            "p",
            "",
            `Illustrative model starting value: $${base}. ` +
            "Condition and storage adjustments are " +
            "reflected in the estimate."
        )
    );

    // Important note
    root.append(
        el(
            "p",
            "seller-note",
            "This is a demonstration estimate, not a " +
            "verified diagnostic result, live appraisal, " +
            "guaranteed sale price, or approved listing. " +
            "Damaged devices may still be useful for parts. " +
            "Account locks must be addressed before any future sale."
        )
    );

    // Navigation
    const navigation = el(
        "div",
        "seller-navigation"
    );

    // Review answers
    const review = el(
        "button",
        "seller-secondary",
        "Review Answers"
    );

    review.addEventListener("click", () => {
        step = questions.length - 1;
        showSellerQuestion();
    });

    // Start over
    const restart = el(
        "button",
        "",
        "Start Over"
    );

    restart.addEventListener("click", () => {
        answers = {};
        step = 0;
        showSellerQuestion();
    });

    // Back to home
    const home = el(
        "button",
        "seller-secondary",
        "Back to Home"
    );

    home.addEventListener("click", () => {
        showPage("home-page");
    });

    navigation.append(
        review,
        restart,
        home
    );

    root.append(navigation);
}

// INITIALIZE WEBSITE
document.addEventListener("DOMContentLoaded", () => {

    const search = document.getElementById(
        "marketplace-search"
    );

    // Enter key opens search placeholder
    search?.addEventListener("keydown", event => {
        if (event.key === "Enter") {
            searchMarketplace();
        }
    });

    // Begin on homepage
    showPage("home-page");
});
