import "dotenv/config";

import path from "path";

import express from "express";

import { config } from "./config";
import authRouter from "./routes/auth";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRouter);

app.use(express.static(path.join(__dirname, "..", "public")));

app.listen(config.port, () => {
  console.log(`Termul backend listening on port ${config.port}`);
});
