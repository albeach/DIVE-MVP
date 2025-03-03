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
</head>

<body class="${properties.kcBodyClass!}">
    <div class="dive25-container">
        <div class="dive25-content">
            <header class="dive25-header">
                <#if realm.internationalizationEnabled && locale.supported?size gt 1>
                    <div class="language-selector">
                        <div class="dropdown">
                            <div class="dropdown-toggle" data-toggle="dropdown">
                                ${locale.current}
                                <i class="fa fa-caret-down"></i>
                            </div>
                            <ul class="dropdown-menu">
                                <#list locale.supported as l>
                                    <li><a href="${l.url}">${l.label}</a></li>
                                </#list>
                            </ul>
                        </div>
                    </div>
                </#if>
                <#nested "header">
            </header>

            <div class="dive25-main">
                <div class="dive25-card">
                    <#-- App-initiated actions should not see warning messages about the need to complete the action -->
                    <#-- during login.                                                                               -->
                    <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                        <div class="alert alert-${message.type}">
                            <#if message.type = 'success'><span class="pficon pficon-success"></span></#if>
                            <#if message.type = 'warning'><span class="pficon pficon-warning-triangle-o"></span></#if>
                            <#if message.type = 'error'><span class="pficon pficon-error-circle-o"></span></#if>
                            <#if message.type = 'info'><span class="pficon pficon-info"></span></#if>
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