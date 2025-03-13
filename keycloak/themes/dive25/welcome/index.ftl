<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="robots" content="noindex, nofollow">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">

    <title>${msg("productName")}</title>
    <link rel="icon" href="${resourcesPath}/img/dive25-favicon.svg">

    <#if properties.stylesCommon?has_content>
        <#list properties.stylesCommon?split(' ') as style>
            <link href="${resourcesCommonPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
</head>

<body>
    <div class="container-fluid">
        <div class="navbar">
            <div class="navbar-pf">
                <div class="navbar-header">
                    <div class="navbar-brand">
                        <div class="navbar-title">${msg("productName")}</div>
                    </div>
                </div>
                <div class="navbar-collapse navbar-collapse-1">
                    <ul class="nav navbar-nav navbar-utility">
                        <#if properties.adminConsole.url?has_content>
                            <li><a href="${properties.adminConsole.url}" target="_blank">${msg("properties.adminConsole.label")}</a></li>
                        </#if>
                        <#if properties.account.url?has_content>
                            <li><a href="${properties.account.url}">${msg("properties.account.label")}</a></li>
                        </#if>
                    </ul>
                </div>
            </div>
        </div>

        <div class="welcome-header">
            <div class="welcome-title">${msg("productName.full")}</div>
            <div class="welcome-subtitle">Secure, controlled access to documents across organizational boundaries</div>
        </div>

        <div class="welcome-content">
            <div class="row">
                <div class="cards-pf">
                    <div class="card-pf">
                        <div class="card-pf-title">
                            Sign In / Register
                        </div>
                        <div class="card-pf-body">
                            <p>Already have an account? Sign in to access the DIVE25 secure document system. New users can register for an account.</p>
                        </div>
                        <div class="card-pf-footer">
                            <a class="card-pf-link" href="${properties.account.url}">Sign In / Register</a>
                        </div>
                    </div>

                    <div class="card-pf">
                        <div class="card-pf-title">
                            Account Management
                        </div>
                        <div class="card-pf-body">
                            <p>Manage your account settings, update profile information, and review security settings from your account dashboard.</p>
                        </div>
                        <div class="card-pf-footer">
                            <a class="card-pf-link" href="${properties.account.url}">Manage Account</a>
                        </div>
                    </div>

                    <div class="card-pf">
                        <div class="card-pf-title">
                            Documentation
                        </div>
                        <div class="card-pf-body">
                            <p>Access comprehensive documentation about using the DIVE25 system, including user guides, FAQs, and security information.</p>
                        </div>
                        <div class="card-pf-footer">
                            <a class="card-pf-link" href="${properties.documentation.url}" target="_blank">View Documentation</a>
                        </div>
                    </div>
                </div>
            </div>

            <div class="row" style="margin-top: 50px;">
                <div class="col-md-12">
                    <div style="text-align: center;">
                        <h2>About DIVE25</h2>
                        <p>DIVE25 (Digital Interoperability Verification Experiment) is a secure system for controlled access to sensitive documents across organizational boundaries. The platform ensures proper authentication, authorization, and auditing of all document access.</p>
                    </div>
                </div>
            </div>
        </div>

        <footer class="footer">
            <div class="footer-content">
                <div class="footer-links">
                    <a href="#">Terms of Service</a>
                    <a href="#">Privacy Policy</a>
                    <a href="#">Security</a>
                    <a href="#">Support</a>
                </div>
                <div class="footer-copyright">
                    © 2023 DIVE25 Project - All Rights Reserved
                </div>
            </div>
        </footer>
    </div>

    <#if properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
</body>
</html> 