// keycloak/themes/dive25/login/resources/js/dive25-scripts.js
document.addEventListener('DOMContentLoaded', function () {
    // Add loading indicator to login button
    const loginButton = document.querySelector('#kc-login');
    if (loginButton) {
        loginButton.addEventListener('click', function (e) {
            // Validate form before submitting
            const form = this.form;
            const username = form.querySelector('#username');
            const password = form.querySelector('#password');

            if (username && !username.value.trim()) {
                e.preventDefault();
                showValidationError(username, 'Please enter your username');
                return;
            }

            if (password && !password.value.trim()) {
                e.preventDefault();
                showValidationError(password, 'Please enter your password');
                return;
            }

            // If validation passes, show loading state
            this.setAttribute('disabled', 'disabled');
            this.value = 'Authenticating...';

            // Add loading spinner
            const originalWidth = this.offsetWidth;
            this.innerHTML = '<span class="loading-spinner"></span> Authenticating...';
            this.style.width = originalWidth + 'px';

            form.submit();
        });
    }

    // Enhanced form validation
    function showValidationError(element, message) {
        // Remove any existing error messages
        const existingError = element.parentNode.querySelector('.error-message');
        if (existingError) {
            existingError.remove();
        }

        // Create and add error message
        const errorSpan = document.createElement('span');
        errorSpan.className = 'error-message';
        errorSpan.textContent = message;
        errorSpan.setAttribute('aria-live', 'polite');

        // Add after the input
        element.parentNode.insertBefore(errorSpan, element.nextSibling);

        // Highlight input
        element.classList.add('error');
        element.setAttribute('aria-invalid', 'true');
        element.focus();

        // Remove error on input
        element.addEventListener('input', function () {
            if (this.value.trim()) {
                const error = this.parentNode.querySelector('.error-message');
                if (error) {
                    error.remove();
                }
                this.classList.remove('error');
                this.setAttribute('aria-invalid', 'false');
            }
        });
    }

    // Enhance identity provider buttons with logos/icons
    const idpButtons = document.querySelectorAll('.social-provider-link');
    if (idpButtons.length > 0) {
        idpButtons.forEach(function (button) {
            const providerName = button.textContent.trim().toLowerCase();

            // Add icon based on provider type
            if (providerName.includes('saml')) {
                button.classList.add('saml-provider');
                button.innerHTML = '<span class="provider-icon">🔑</span> ' + button.textContent;
            } else if (providerName.includes('oidc')) {
                button.classList.add('oidc-provider');
                button.innerHTML = '<span class="provider-icon">🔒</span> ' + button.textContent;
            } else if (providerName.includes('google')) {
                button.classList.add('google-provider');
                button.innerHTML = '<span class="provider-icon">G</span> ' + button.textContent;
            } else if (providerName.includes('microsoft')) {
                button.classList.add('microsoft-provider');
                button.innerHTML = '<span class="provider-icon">M</span> ' + button.textContent;
            } else if (providerName.includes('facebook')) {
                button.classList.add('facebook-provider');
                button.innerHTML = '<span class="provider-icon">f</span> ' + button.textContent;
            } else if (providerName.includes('github')) {
                button.classList.add('github-provider');
                button.innerHTML = '<span class="provider-icon">GH</span> ' + button.textContent;
            }
        });
    }

    // Add password visibility toggle
    const passwordInput = document.getElementById('password');
    if (passwordInput) {
        const container = passwordInput.parentNode;

        // Create toggle button
        const toggleButton = document.createElement('button');
        toggleButton.type = 'button';
        toggleButton.className = 'password-toggle';
        toggleButton.setAttribute('aria-label', 'Toggle password visibility');
        toggleButton.innerHTML = '👁️';

        // Insert toggle button
        container.appendChild(toggleButton);

        // Add toggle functionality
        toggleButton.addEventListener('click', function () {
            const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
            passwordInput.setAttribute('type', type);
            this.innerHTML = type === 'password' ? '👁️' : '👁️‍🗨️';
        });
    }

    // Add remember me label enhancement
    const rememberMe = document.getElementById('rememberMe');
    if (rememberMe) {
        const label = rememberMe.closest('label');
        if (label) {
            label.classList.add('remember-me-label');
        }
    }

    // Add animation to alerts
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(function (alert) {
        alert.style.opacity = '0';
        alert.style.transform = 'translateY(-10px)';
        alert.style.transition = 'opacity 0.3s ease, transform 0.3s ease';

        setTimeout(function () {
            alert.style.opacity = '1';
            alert.style.transform = 'translateY(0)';
        }, 100);
    });

    // Add CSS keyframes for loading spinner
    const style = document.createElement('style');
    style.textContent = `
        @keyframes spinner {
            to { transform: rotate(360deg); }
        }
        .loading-spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spinner 0.8s linear infinite;
            margin-right: 8px;
            vertical-align: middle;
        }
        .error {
            border-color: var(--dive25-danger) !important;
        }
        .password-toggle {
            position: absolute;
            right: 10px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            cursor: pointer;
            padding: 5px;
        }
        .provider-icon {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 24px;
            height: 24px;
            margin-right: 8px;
            border-radius: 50%;
            background: rgba(0,0,0,0.1);
            font-weight: bold;
        }
    `;
    document.head.appendChild(style);
});
