// keycloak/themes/dive25/admin/resources/js/dive25-admin.js
document.addEventListener('DOMContentLoaded', function () {
    // Add DIVE25 version info to the footer
    const footerElement = document.querySelector('.navbar-footer');
    if (footerElement) {
        const versionElement = document.createElement('div');
        versionElement.className = 'dive25-version';
        versionElement.textContent = 'DIVE25 v1.0.0';
        footerElement.appendChild(versionElement);
    }

    // Add DIVE25 branding to the sidebar
    const sidebarElement = document.querySelector('#sidebar');
    if (sidebarElement) {
        // Add custom styling for sidebar
        sidebarElement.classList.add('dive25-sidebar');
    }

    // Enhance button interactions
    const primaryButtons = document.querySelectorAll('.btn-primary');
    primaryButtons.forEach(function (button) {
        button.addEventListener('mousedown', function () {
            this.style.transform = 'scale(0.98)';
        });

        button.addEventListener('mouseup', function () {
            this.style.transform = 'scale(1)';
        });

        button.addEventListener('mouseleave', function () {
            this.style.transform = 'scale(1)';
        });
    });

    // Add custom help tooltips for DIVE25 specific features
    const dive25Elements = document.querySelectorAll('[data-dive25-help]');
    dive25Elements.forEach(function (element) {
        const helpText = element.getAttribute('data-dive25-help');
        const helpIcon = document.createElement('span');
        helpIcon.className = 'pficon pficon-help dive25-help-icon';
        helpIcon.title = helpText;

        element.appendChild(helpIcon);
    });

    // Add fade-in animation for page content
    const pageContent = document.querySelector('#content');
    if (pageContent) {
        pageContent.style.opacity = '0';
        pageContent.style.transition = 'opacity 0.3s ease';

        setTimeout(function () {
            pageContent.style.opacity = '1';
        }, 100);
    }

    // Add confirmation for dangerous actions
    const dangerousButtons = document.querySelectorAll('.btn-danger, [data-dive25-confirm]');
    dangerousButtons.forEach(function (button) {
        button.addEventListener('click', function (e) {
            if (!this.hasAttribute('data-confirmed')) {
                e.preventDefault();

                const confirmMessage = this.getAttribute('data-dive25-confirm') || 'Are you sure you want to perform this action?';

                if (confirm(confirmMessage)) {
                    this.setAttribute('data-confirmed', 'true');
                    this.click();
                }
            }

            // Reset the confirmation for next time
            this.removeAttribute('data-confirmed');
        });
    });

    // Add keyboard shortcuts for common actions
    document.addEventListener('keydown', function (e) {
        // Alt+S for search
        if (e.altKey && e.key === 's') {
            e.preventDefault();
            const searchInput = document.querySelector('#search');
            if (searchInput) {
                searchInput.focus();
            }
        }

        // Alt+H for help
        if (e.altKey && e.key === 'h') {
            e.preventDefault();
            const helpLink = document.querySelector('[data-help-url]');
            if (helpLink) {
                window.open(helpLink.getAttribute('data-help-url'), '_blank');
            }
        }
    });
}); 