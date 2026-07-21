import express from "express";
import commerceFeedRouter from "./routes/commerceFeed.js";

const app = express();
const PORT = parseInt(process.env.PORT ?? "3000", 10);

app.use(express.json());

app.use(commerceFeedRouter);

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.listen(PORT, () => {
  console.log(`[wirecutter-api] Server running on http://localhost:${PORT}`);
  console.log(`[wirecutter-api] Commerce feed: GET http://localhost:${PORT}/wirecutter/commerce-feed`);
});
