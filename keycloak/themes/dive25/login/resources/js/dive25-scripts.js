// keycloak/themes/dive25/login/resources/js/dive25-scripts.js
// Add loading indicator to login button
document.addEventListener('DOMContentLoaded', function () {
    var loginButton = document.querySelector('#kc-login');
    if (loginButton) {
        loginButton.addEventListener('click', function () {
            this.setAttribute('disabled', 'disabled');
            this.value = 'Authenticating...';
            this.form.submit();
        });
    }

    // Enhance identity provider buttons with logos/icons
    var idpButtons = document.querySelectorAll('.social-provider-link');
    if (idpButtons.length > 0) {
        idpButtons.forEach(function (button) {
            var providerName = button.textContent.trim().toLowerCase();
            if (providerName.includes('saml')) {
                button.classList.add('saml-provider');
            } else if (providerName.includes('oidc')) {
                button.classList.add('oidc-provider');
            }
        });
    }
});
