
/* JUNGLE MARKETPLACE */

/*
Current prototype:
Home page is functional.
Seller and buyer features are under development.
JUNGLE focuses on phones and tablets.
*/

// Titles and descriptions for future pages
const pages = {
    "sell-page": {
        title: "Sell a Device",
        message:
            "Coming Soon! We're developing a device assessment " +
            "to help you estimate the value of your phone or tablet."
    },

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

    const comingSoonPage =
        document.getElementById("coming-soon-page");

    // Return to homepage
    if (pageId === "home-page") {
        homePage.hidden = false;
        comingSoonPage.hidden = true;

        window.scrollTo({
            top: 0,
            behavior: "smooth"
        });

        return;
    }

    // Find the selected placeholder
    const selectedPage = pages[pageId];

    if (!selectedPage) {
        showPage("home-page");
        return;
    }

    // Update placeholder content
    document.getElementById(
        "coming-soon-title"
    ).textContent = selectedPage.title;

    document.getElementById(
        "coming-soon-message"
    ).textContent = selectedPage.message;

    // Hide homepage and show placeholder
    homePage.hidden = true;
    comingSoonPage.hidden = false;

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
