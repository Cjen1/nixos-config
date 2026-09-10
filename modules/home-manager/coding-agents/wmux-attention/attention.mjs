export const ATTENTION_DELAY_MS = 1500;

// This observer never approves, denies, or changes a permission request.
export async function watchPermissions(session, {
    notify,
    log,
    setTimer = setTimeout,
    clearTimer = clearTimeout,
}) {
    const pending = new Map();
    const completedDuringHydration = new Set();
    let hydrating = true;
    let disposed = false;

    function cancel(requestId) {
        const entry = pending.get(requestId);
        if (!entry) return;
        clearTimer(entry.timer);
        pending.delete(requestId);
        log(`resolved ${requestId}${entry.alerted ? " after alert" : " before alert"}`);
    }

    function schedule(requestId) {
        if (disposed || pending.has(requestId)) return;
        const entry = { alerted: false, timer: undefined };
        entry.timer = setTimer(() => {
            try {
                notify({
                    sessionId: session.sessionId,
                    requestId,
                    notificationType: "permission_prompt",
                    message: "Copilot has a pending permission request",
                });
                entry.alerted = true;
                log(`alert ${requestId}`);
            } catch (error) {
                log(`ERROR delivering ${requestId}: ${error.message}`);
            }
        }, ATTENTION_DELAY_MS);
        pending.set(requestId, entry);
        log(`pending ${requestId}`);
    }

    const unsubscribe = session.on((event) => {
        if (event.type === "permission.completed") {
            if (hydrating) completedDuringHydration.add(event.data.requestId);
            cancel(event.data.requestId);
        } else if (event.type === "permission.requested") {
            if (!event.data.resolvedByHook) schedule(event.data.requestId);
        }
    });

    function dispose() {
        disposed = true;
        unsubscribe();
        for (const entry of pending.values()) clearTimer(entry.timer);
        pending.clear();
    }

    try {
        // Subscribe before the snapshot so a completion cannot resurrect a
        // stale request while the RPC is in flight.
        const snapshot = await session.rpc.permissions.pendingRequests();
        for (const item of snapshot.items) {
            if (!completedDuringHydration.has(item.requestId)) schedule(item.requestId);
        }
    } catch (error) {
        dispose();
        throw error;
    } finally {
        hydrating = false;
        completedDuringHydration.clear();
    }
    log("ready");
    return dispose;
}
