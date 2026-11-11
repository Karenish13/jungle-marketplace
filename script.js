function showPage(pageId) {
  document.querySelectorAll(".page").forEach(page => {
    page.classList.add("hidden");
  });
document.getElementyById(pageId).classList.add("hidden");
}

function searchparts() {
  const device = document.getElementById("buyer-model").value;
  const part = document.getElementbyId("part").value;

  document.getElementById("results").textContent = 
    Searching for ${part.toLowerCase()} parts for ${device}. 
    This is a protype. Compatibility is not verified. ';
}

  
