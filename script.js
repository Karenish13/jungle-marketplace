const products = [
    {
        name: "iPhone 12 Screen",
        category: "Phones",
        price: 59,
        condition: "Good",
        status: "Evidence Submitted",
        icon: "📱"
    },
    {
        name: "iPhone 12 Battery",
        category: "Phones",
        price: 32,
        condition: "Used",
        status: "Self Reported",
        icon: "🔋"
    },
    {
        name: "Phone Camera Module",
        category: "Phones",
        price: 45,
        condition: "Good",
        status: "Evidence Submitted",
        icon: "📷"
    },
    {
        name: "MacBook Keyboard",
        category: "Laptops",
        price: 38,
        condition: "Good",
        status: "Self Reported",
        icon: "💻"
    },
    {
        name: "iPad Charging Port",
        category: "Tablets",
        price: 25,
        condition: "Used",
        status: "Evidence Submitted",
        icon: "📟"
    },
    {
        name: "Nintendo Switch Joy-Con",
        category: "Gaming",
        price: 29,
        condition: "Good",
        status: "Self Reported",
        icon: "🎮"
    }
];

// Display products on the homepage
function displayProducts(items) {
    const container =
        document.getElementById("featured-listings");

    if (!container) return;

    container.innerHTML = "";

    if (items.length === 0) {
        container.textContent =
            "No matching products found.";
        return;
    }

    items.forEach(product => {
        const card = document.createElement("article");
        card.className = "listing-card";

        card.innerHTML = `
            <div class="product-image">
                ${product.icon}
            </div>
            <h3>${product.name}</h3>
            <p>Condition: ${product.condition}</p>
            <span class="status">
                ${product.status}
            </span>
            <strong>$${product.price}</strong>
        `;

        container.appendChild(card);
    });
}

// Search marketplace listings
function searchMarketplace() {
    const searchInput =
        document.getElementById("marketplace-search");

    const searchTerm =
        searchInput.value.toLowerCase().trim();

    const matches = products.filter(product =>
        product.name.toLowerCase().includes(searchTerm) ||
        product.category.toLowerCase().includes(searchTerm)
    );

    displayProducts(matches);

    document.querySelector(".featured")
        ?.scrollIntoView({ behavior: "smooth" });
}

// Browse product categories
function filterCategory(category) {
    const matches = products.filter(product =>
        product.category === category
    );

    displayProducts(matches);

    document.querySelector(".featured")
        ?.scrollIntoView({ behavior: "smooth" });
}

// Navigate between prototype screens
function showPage(pageId) {
    const pageNames = {
        "home-page": "Home",
        "explore-page": "Explore Parts",
        "sell-page": "Sell a Device",
        "listings-page": "My Listings",
        "profile-page": "Profile"
    };

    if (pageId === "home-page") {
        window.scrollTo({ top: 0, behavior: "smooth" });
        return;
    }

    const pageName = pageNames[pageId];

    if (!pageName) return;

    alert(
        `${pageName} is the next JUNGLE screen ` +
        "we will build!"
    );
}

// Initialize the marketplace
document.addEventListener("DOMContentLoaded", () => {
    displayProducts(products);

    const searchInput =
        document.getElementById("marketplace-search");

    if (searchInput) {
        searchInput.addEventListener("keydown", event => {
            if (event.key === "Enter") {
                searchMarketplace();
            }
        });
    }
});
