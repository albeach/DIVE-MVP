<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
    <#if section = "header">
        <div class="login-header animated-fade-in">
            <div class="w-24 h-24 mx-auto bg-white/10 backdrop-blur-sm rounded-2xl p-3 border border-white/20 shadow-lg">
                <img src="${url.resourcesPath}/img/dive25-logo.svg" alt="DIVE25 Logo" class="login-logo">
            </div>
            <h1>${msg("loginTitle")}</h1>
            <p>${msg("loginWelcomeMessage")}</p>
        </div>
    <#elseif section = "form">
        <div id="kc-form" class="animated-fade-in" style="animation-delay: 0.1s;">
            <div id="kc-form-wrapper">
                <#if realm.password>
                    <form id="kc-form-login" onsubmit="return true;" action="${url.loginAction}" method="post">
                        <div class="form-group">
                            <label for="username" class="form-label">${msg("username")}</label>
                            <input tabindex="1" id="username" class="form-control" name="username" value="${(login.username!'')}" type="text" autofocus autocomplete="off"
                                   aria-invalid="<#if messagesPerField.existsError('username')>true</#if>"
                                   placeholder="Enter your username"
                            />
                            <#if messagesPerField.existsError('username')>
                                <span id="input-error-username" class="text-white/90 text-sm mt-2 block" aria-live="polite">
                                    ${kcSanitize(messagesPerField.get('username'))?no_esc}
                                </span>
                            </#if>
                        </div>

                        <div class="form-group">
                            <label for="password" class="form-label">${msg("password")}</label>
                            <div class="password-container">
                                <input tabindex="2" id="password" class="form-control" name="password" type="password" autocomplete="off"
                                       aria-invalid="<#if messagesPerField.existsError('password')>true</#if>"
                                       placeholder="Enter your password"
                                />
                                <#if messagesPerField.existsError('password')>
                                    <span id="input-error-password" class="text-white/90 text-sm mt-2 block" aria-live="polite">
                                        ${kcSanitize(messagesPerField.get('password'))?no_esc}
                                    </span>
                                </#if>
                            </div>
                        </div>

                        <div class="form-group login-options">
                            <#if realm.rememberMe && !usernameEditDisabled??>
                                <div class="checkbox">
                                    <label>
                                        <#if login.rememberMe??>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" checked> ${msg("rememberMe")}
                                        <#else>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox"> ${msg("rememberMe")}
                                        </#if>
                                    </label>
                                </div>
                            </#if>
                            <div class="forgot-password">
                                <#if realm.resetPasswordAllowed>
                                    <a tabindex="5" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
                                </#if>
                            </div>
                        </div>

                        <div id="kc-form-buttons" class="form-group">
                            <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                            <input tabindex="4" class="btn btn-primary btn-block btn-lg" name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                        </div>
                    </form>
                </#if>
            </div>
        </div>
    <#elseif section = "info">
        <div id="kc-registration" class="text-center mt-6 animated-fade-in" style="animation-delay: 0.2s;">
            <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
                <div class="register-link">
                    <span class="text-white/90">${msg("noAccount")} <a tabindex="6" href="${url.registrationUrl}" class="text-white font-medium hover:underline">${msg("doRegister")}</a></span>
                </div>
            </#if>
        </div>

        <#if realm.password && social.providers??>
            <div id="kc-social-providers" class="social-providers mt-10 animated-fade-in" style="animation-delay: 0.3s;">
                <hr class="border-white/10 mb-6"/>
                <h4 class="text-center text-lg mb-4 text-white/90">${msg("identity-provider-login-label",realm.displayName)}</h4>

                <ul class="space-y-3">
                    <#list social.providers as p>
                        <li>
                            <a id="social-${p.alias}" class="bg-white/10 hover:bg-white/20 text-white border border-white/10 hover:border-white/20 backdrop-blur-sm shadow-sm transition-all duration-300 rounded-xl flex items-center justify-center px-4 py-3 w-full" href="${p.loginUrl}">
                                <span>${p.displayName}</span>
                            </a>
                        </li>
                    </#list>
                </ul>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout> 