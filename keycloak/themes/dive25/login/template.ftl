<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}">

<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="robots" content="noindex, nofollow">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>${msg("loginTitle",(realm.displayName!''))}</title>
    <link rel="icon" href="${url.resourcesPath}/img/dive25-favicon.svg" />

    <#if properties.stylesCommon?has_content>
        <#list properties.stylesCommon?split(' ') as style>
            <link href="${url.resourcesCommonPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${url.resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
    
    <!-- Add inline styles for critical rendering -->
    <style>
        body:not(.loaded) {
            opacity: 0;
        }
        body.loaded {
            opacity: 1;
            transition: opacity 0.5s ease-in-out;
        }
    </style>
</head>

<body class="${properties.kcBodyClass!}" onload="document.body.classList.add('loaded')">
    <!-- Background decorative elements -->
    <div class="decorative-orb-right"></div>
    <div class="decorative-orb-left"></div>
    <div class="decorative-orb-bottom"></div>
    
    <div class="dive25-container">
        <div class="dive25-content">
            <header class="dive25-header">
                <#if realm.internationalizationEnabled && locale.supported?size gt 1>
                    <div class="language-selector">
                        <div class="dropdown" style="position: relative;">
                            <div class="dropdown-toggle" onclick="toggleLanguageDropdown()" style="cursor: pointer; background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(8px); padding: 8px 12px; border-radius: 8px; display: inline-block;">
                                <span>${locale.current}</span>
                                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display: inline-block; vertical-align: middle; margin-left: 6px;"><polyline points="6 9 12 15 18 9"></polyline></svg>
                            </div>
                            <ul id="language-dropdown" class="dropdown-menu" style="position: absolute; right: 0; margin-top: 4px; background: rgba(255, 255, 255, 0.15); backdrop-filter: blur(16px); border-radius: 8px; overflow: hidden; display: none; min-width: 150px; box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.1);">
                                <#list locale.supported as l>
                                    <li style="border-bottom: 1px solid rgba(255, 255, 255, 0.05);">
                                        <a href="${l.url}" style="display: block; padding: 10px 16px; color: white; text-decoration: none; transition: all 0.15s;">${l.label}</a>
                                    </li>
                                </#list>
                            </ul>
                        </div>
                        <script>
                            function toggleLanguageDropdown() {
                                const dropdown = document.getElementById('language-dropdown');
                                dropdown.style.display = dropdown.style.display === 'block' ? 'none' : 'block';
                            }
                            
                            document.addEventListener('click', function(event) {
                                const dropdown = document.getElementById('language-dropdown');
                                const toggle = document.querySelector('.dropdown-toggle');
                                if (!toggle.contains(event.target) && !dropdown.contains(event.target)) {
                                    dropdown.style.display = 'none';
                                }
                            });
                        </script>
                    </div>
                </#if>
                <#nested "header">
            </header>

            <div class="dive25-main">
                <div class="dive25-card">
                    <#-- App-initiated actions should not see warning messages about the need to complete the action -->
                    <#-- during login.                                                                               -->
                    <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                        <div class="alert alert-${message.type} animated-fade-in">
                            <#if message.type = 'success'>
                                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>
                            </#if>
                            <#if message.type = 'warning'>
                                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>
                            </#if>
                            <#if message.type = 'error'>
                                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>
                            </#if>
                            <#if message.type = 'info'>
                                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>
                            </#if>
                            <span class="kc-feedback-text">${kcSanitize(message.summary)?no_esc}</span>
                        </div>
                    </#if>

                    <#nested "form">

                    <#if displayInfo>
                        <div class="dive25-info-box">
                            <#nested "info">
                        </div>
                    </#if>
                </div>
            </div>

            <footer class="dive25-footer">
                <div class="footer-content">
                    <div class="footer-links">
                        <a href="#">Terms of Service</a>
                        <a href="#">Privacy Policy</a>
                        <a href="#">Documentation</a>
                        <a href="#">Support</a>
                    </div>
                    <div class="footer-copyright">
                        &copy; ${.now?string('yyyy')} DIVE25 Project - All Rights Reserved
                    </div>
                </div>
            </footer>
        </div>
    </div>
</body>
</html>
</#macro> 