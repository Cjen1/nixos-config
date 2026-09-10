import { execFileSync } from "node:child_process";
import { joinSession } from "@github/copilot-sdk/extension";
import { watchPermissions } from "./attention.mjs";
import { hookCommand, dryRun } from "./config.mjs";

const log = (message) => console.error(`[wmux-attention] ${message}`);
const session = await joinSession();
const dispose = await watchPermissions(session, {
    log,
    notify(payload) {
        if (dryRun) {
            log(`dry-run notification ${payload.requestId}`);
            return;
        }
        execFileSync(hookCommand, ["notification"], {
            input: JSON.stringify(payload),
            stdio: ["pipe", "ignore", "pipe"],
            timeout: 1500,
        });
    },
});
log(dryRun ? "observe mode: no notifications emitted" : "notify mode");

process.once("SIGTERM", () => {
    dispose();
    process.exit(0);
});
