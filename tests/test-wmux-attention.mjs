import assert from "node:assert/strict";
import { test } from "node:test";
import {
    ATTENTION_DELAY_MS,
    watchPermissions,
} from "../modules/home-manager/coding-agents/wmux-attention/attention.mjs";

function fixture(snapshot = async () => ({ items: [] })) {
    let now = 0;
    let handler;
    let unsubscribed = false;
    const timers = new Map();
    const notifications = [];
    const logs = [];
    const session = {
        sessionId: "session-test",
        on(callback) {
            handler = callback;
            return () => { unsubscribed = true; };
        },
        rpc: { permissions: { pendingRequests: snapshot } },
    };
    const options = {
        notify: (payload) => notifications.push(payload),
        log: (message) => logs.push(message),
        setTimer(callback, delay) {
            const timer = { callback, at: now + delay };
            timers.set(timer, timer);
            return timer;
        },
        clearTimer: (timer) => timers.delete(timer),
    };
    return {
        session, options, notifications, logs, timers,
        get unsubscribed() { return unsubscribed; },
        event(type, requestId, data = {}) {
            if (!unsubscribed) handler({ type, data: { requestId, ...data } });
        },
        advance(ms) {
            now += ms;
            for (const timer of timers.values()) {
                if (timer.at <= now) {
                    timers.delete(timer);
                    timer.callback();
                }
            }
        },
    };
}

test("observed 58-149ms autopilot approvals produce no attention alerts", async () => {
    for (const latency of [58, 149, 129, 149, 109, 72]) {
        const f = fixture();
        const dispose = await watchPermissions(f.session, f.options);
        f.event("permission.requested", "auto");
        f.advance(latency);
        f.event("permission.completed", "auto");
        f.advance(ATTENTION_DELAY_MS);
        assert.deepEqual(f.notifications, []);
        assert.match(f.logs.join("\n"), /resolved auto before alert/);
        dispose();
    }
});

test("unresolved permission alerts once at the threshold, including an approve recommendation", async () => {
    const f = fixture();
    const dispose = await watchPermissions(f.session, f.options);
    f.event("permission.requested", "pending", {
        promptRequest: { assistedApproval: { recommendation: "approve" } },
    });
    f.advance(ATTENTION_DELAY_MS - 1);
    assert.equal(f.notifications.length, 0);
    f.advance(1);
    assert.deepEqual(f.notifications, [{
        sessionId: "session-test",
        requestId: "pending",
        notificationType: "permission_prompt",
        message: "Copilot has a pending permission request",
    }]);
    f.event("permission.requested", "pending");
    f.advance(ATTENTION_DELAY_MS * 10);
    assert.equal(f.notifications.length, 1);
    f.event("permission.completed", "pending");
    assert.match(f.logs.join("\n"), /resolved pending after alert/);
    dispose();
});

test("concurrent requests cancel independently and hook-resolved requests never alert", async () => {
    const f = fixture();
    const dispose = await watchPermissions(f.session, f.options);
    f.event("permission.requested", "first");
    f.event("permission.requested", "second");
    f.event("permission.requested", "hook", { resolvedByHook: true });
    f.event("permission.completed", "first");
    f.advance(ATTENTION_DELAY_MS);
    assert.deepEqual(f.notifications.map((n) => n.requestId), ["second"]);
    dispose();
});

test("snapshot recovers outstanding prompts without reviving completed requests", async () => {
    let resolveSnapshot;
    const snapshot = new Promise((resolve) => { resolveSnapshot = resolve; });
    const f = fixture(() => snapshot);
    const started = watchPermissions(f.session, f.options);
    f.event("permission.completed", "stale");
    f.event("permission.requested", "live");
    resolveSnapshot({ items: [
        { requestId: "stale" },
        { requestId: "live" },
        { requestId: "before-attach" },
    ] });
    const dispose = await started;
    f.advance(ATTENTION_DELAY_MS);
    assert.deepEqual(f.notifications.map((n) => n.requestId), ["live", "before-attach"]);
    dispose();
});

test("stop cancels timers and unsubscribes", async () => {
    const f = fixture();
    const dispose = await watchPermissions(f.session, f.options);
    f.event("permission.requested", "pending");
    dispose();
    f.advance(ATTENTION_DELAY_MS);
    assert.equal(f.timers.size, 0);
    assert.equal(f.unsubscribed, true);
    assert.deepEqual(f.notifications, []);
});

test("unsupported snapshot RPC fails visibly and removes listeners", async () => {
    const f = fixture(async () => { throw new Error("RPC unavailable"); });
    await assert.rejects(watchPermissions(f.session, f.options), /RPC unavailable/);
    assert.equal(f.unsubscribed, true);
    assert.equal(f.timers.size, 0);
});

test("delivery errors are logged instead of reported as successful alerts", async () => {
    const f = fixture();
    f.options.notify = () => { throw new Error("No controlling terminal"); };
    const dispose = await watchPermissions(f.session, f.options);
    f.event("permission.requested", "pending");
    f.advance(ATTENTION_DELAY_MS);
    assert.match(f.logs.join("\n"), /ERROR delivering pending: No controlling terminal/);
    assert.ok(!f.logs.includes("alert pending"));
    dispose();
});

test("unrelated requests and lifecycle events remain the existing hooks' responsibility", async () => {
    const f = fixture();
    const dispose = await watchPermissions(f.session, f.options);
    for (const type of ["user_input.requested", "elicitation.requested", "session.idle"]) {
        f.event(type, "unrelated");
    }
    f.advance(ATTENTION_DELAY_MS);
    assert.deepEqual(f.notifications, []);
    dispose();
});
