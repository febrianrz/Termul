import "dotenv/config";

import express from "express";

import { config } from "./config";
import authRouter from "./routes/auth";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRouter);

app.listen(config.port, () => {
  console.log(`Termul backend listening on port ${config.port}`);
});
