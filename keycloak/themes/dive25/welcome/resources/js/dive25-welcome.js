// keycloak/themes/dive25/welcome/resources/js/dive25-welcome.js
document.addEventListener('DOMContentLoaded', function () {
    // Add DIVE25 logo to the welcome page
    const headerElement = document.querySelector('.welcome-header');
    if (headerElement) {
        const logoImg = document.createElement('img');
        logoImg.src = '/auth/resources/9nxr4/welcome/dive25/img/dive25-logo.svg';
        logoImg.alt = 'DIVE25 Logo';
        logoImg.className = 'logo';

        // Insert logo at the beginning of the header
        headerElement.insertBefore(logoImg, headerElement.firstChild);
    }

    // Add version information to the footer
    const footerElement = document.querySelector('.footer-content');
    if (footerElement) {
        const versionElement = document.createElement('div');
        versionElement.className = 'footer-version';
        versionElement.textContent = 'DIVE25 v1.0.0';
        footerElement.appendChild(versionElement);
    }

    // Add smooth animations to the cards
    const cards = document.querySelectorAll('.card-pf');
    cards.forEach(function (card, index) {
        // Add delay to each card for staggered animation
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = 'opacity 0.5s ease, transform 0.5s ease';

        setTimeout(function () {
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
        }, 100 + (index * 100)); // Stagger the animations
    });

    // Add current year to copyright in footer
    const currentYear = new Date().getFullYear();
    const copyrightElement = document.querySelector('.footer-copyright');
    if (copyrightElement) {
        copyrightElement.textContent = `© ${currentYear} DIVE25 Project - All Rights Reserved`;
    }

    // Add feedback for card links
    const cardLinks = document.querySelectorAll('.card-pf-link');
    cardLinks.forEach(function (link) {
        link.addEventListener('click', function (e) {
            // Don't add this effect for links that open in new tabs
            if (!this.getAttribute('target') || this.getAttribute('target') !== '_blank') {
                e.preventDefault();

                // Add feedback
                this.textContent = 'Redirecting...';

                // Redirect after a short delay
                const href = this.getAttribute('href');
                setTimeout(function () {
                    window.location.href = href;
                }, 300);
            }
        });
    });
}); 