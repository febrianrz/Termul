function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

// Nothing provider-specific is hardcoded as required config - forks point
// this at their own OAuth2 SSO server via env vars. The defaults below just
// match this repo's own deployment (Alter Indonesia).
export const config = {
  port: process.env.PORT ? Number(process.env.PORT) : 3000,
  ssoBaseUrl: process.env.SSO_BASE_URL ?? "https://one.alterindonesia.com",
  ssoClientId: requireEnv("SSO_CLIENT_ID"),
  ssoClientSecret: requireEnv("SSO_CLIENT_SECRET"),
  ssoRedirectUri:
    process.env.SSO_REDIRECT_URI ?? "com.febrianrz.termul://callback",
};
