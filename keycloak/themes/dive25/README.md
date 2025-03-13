# DIVE25 Keycloak Theme

A custom Keycloak theme for the DIVE25 (Digital Interoperability Verification Experiment) platform. This theme provides a consistent, branded experience across all Keycloak interfaces.

## Overview

This theme includes customizations for:

- **Login Theme**: Authentication screens (login, registration, forgot password, etc.)
- **Welcome Theme**: The landing/welcome page
- **Admin Theme**: The admin console
- **Account Theme**: User account management

## Structure

```
dive25/
├── login/              # Login interface theme
│   ├── resources/      # Static resources (CSS, JS, images) 
│   ├── theme.properties
│   ├── login.ftl       # Login page template
│   └── template.ftl    # Base template
├── welcome/            # Welcome page theme
│   ├── resources/      # Static resources
│   ├── theme.properties
│   └── index.ftl       # Welcome page template
├── admin/              # Admin console theme
│   ├── resources/      # Static resources
│   └── theme.properties
└── README.md           # This documentation
```

## Installation and Usage

### Automatic Installation

Use the provided script to update the theme:

```bash
# Update the theme in the Keycloak container
./update-theme-docker.sh
```

### Manual Installation

To manually install the theme:

1. Copy the `dive25` directory to the Keycloak themes directory:
   ```bash
   cp -r dive25 /path/to/keycloak/themes/
   ```

2. Set the theme in the Keycloak admin console:
   - Go to Realm Settings
   - Open the Themes tab
   - Select "dive25" for Login Theme, Account Theme, Admin Console Theme, and Email Theme

## Customization

### Colors

The theme uses CSS variables defined in the root of each CSS file:

```css
:root {
    --dive25-primary: #003366;
    --dive25-secondary: #0066cc;
    --dive25-accent: #ff9900;
    --dive25-background: #f5f5f5;
    /* ... other variables ... */
}
```

To change colors, edit these variables in:
- `login/resources/css/dive25-styles.css`
- `welcome/resources/css/dive25-welcome.css`
- `admin/resources/css/dive25-admin.css`

### Images

- Logo: `login/resources/img/dive25-logo.svg`
- Favicon: `login/resources/img/dive25-favicon.svg`

Replace these files to update the images.

### Labels and Text

Text labels are defined in the `theme.properties` files. Edit these files to change text and labels:

- `login/theme.properties`
- `welcome/theme.properties`
- `admin/theme.properties`

## Testing

To test the theme:

```bash
# Run the test script
./test-theme.sh
```

## Development

1. Make changes to the theme files
2. Run `./update-theme-docker.sh` to update the theme in the Keycloak container
3. Test your changes in the browser
4. Restart Keycloak if necessary: `docker restart dive25-keycloak` 