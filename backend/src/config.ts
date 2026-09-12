function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  port: process.env.PORT ? Number(process.env.PORT) : 3000,
  alterBaseUrl: process.env.ALTER_BASE_URL ?? "https://one.alterindonesia.com",
  alterClientId: requireEnv("ALTER_CLIENT_ID"),
  alterClientSecret: requireEnv("ALTER_CLIENT_SECRET"),
  alterRedirectUri:
    process.env.ALTER_REDIRECT_URI ?? "com.febrianrz.termul://callback",
};
