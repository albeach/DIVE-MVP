# Connecting Frontend to Keycloak with DIVE25 Theme

This document explains how the frontend connects to Keycloak using the DIVE25 custom theme.

## Configuration

The frontend uses the following environment variables to connect to Keycloak:

```
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=dive25
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=dive25-frontend
```

These can be found in the `.env.local` file.

## Theme Integration

The DIVE25 theme has been integrated with the frontend in the following ways:

1. **CSS Variables**: The `src/styles/keycloak-theme.css` file contains CSS variables that match the DIVE25 Keycloak theme.

2. **Shared Assets**: The logo and favicon from the Keycloak theme are shared with the frontend and stored in `public/assets/`.

3. **Login Page**: The login page at `src/pages/login.tsx` uses the same styling as the Keycloak theme.

4. **Silent Check SSO**: The `public/silent-check-sso.html` file enables seamless SSO between the frontend and Keycloak.

## Authentication Flow

1. When a user clicks the login button, they are redirected to Keycloak.
2. Keycloak displays the login page using the DIVE25 theme.
3. After successful authentication, the user is redirected back to the frontend.
4. The frontend uses the token from Keycloak to authenticate API requests.

## Testing the Theme

To test that the theme is working correctly:

1. Start the Keycloak server with the DIVE25 theme:
   ```
   ./keycloak/update-theme-docker.sh
   ```

2. Start the frontend:
   ```
   cd frontend
   npm run dev
   ```

3. Visit `http://localhost:3000/login` and click "Sign in with Keycloak".
4. You should see the DIVE25 themed login page on Keycloak.

## Troubleshooting

### Theme Not Appearing

If the DIVE25 theme is not appearing in Keycloak, make sure:

1. The theme has been correctly copied to the Keycloak container using `update-theme-docker.sh`.
2. The dive25 realm has been configured to use the DIVE25 theme in the Keycloak admin console.

### Authentication Issues

If authentication is not working, check:

1. The client settings in Keycloak match the `NEXT_PUBLIC_KEYCLOAK_CLIENT_ID` in the frontend.
2. Valid redirect URIs are configured in the Keycloak client settings.
3. Web origins are properly configured in the Keycloak client settings.

## Advanced Configuration

For development with different environments, create environment-specific files like `.env.development` or `.env.production` with the appropriate Keycloak URL and client settings. 