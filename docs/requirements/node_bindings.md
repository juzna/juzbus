# Node ↔ Obj-C Framework XPC Bindings – Requirements & Implementation Plan

## 1. Goal

Provide a **Node.js / Bun binding** that interacts with macOS **XPC services** via a **native Objective‑C framework**, loaded **in‑process** (no helper IPC process).

The binding must:

- Allow Node to act as an **XPC client** (directory + instance)
- Allow Node to act as an **XPC service instance** (register + receive commands)
- Reuse the existing **LaunchAgent directory service**
- Avoid spawning helper processes
- Expose a **stable C ABI** to Node
- Keep Objective‑C / Swift implementation details hidden

This document is intended to be handed directly to a coding agent.

---

## 2. Explicit Non‑Goals (Important)

- Node **does not** interact with Swift directly
- Node **does not** use NSXPC APIs directly
- No Swift symbols are exposed to Node
- No global Mach port usage from Node
- No JavaScript ↔ Objective‑C object sharing

---

## 3. High‑Level Architecture

```
Node (Bun / Node.js)
   |
   |  FFI / N‑API / dlopen
   v
C ABI Shim (extern "C")   ← stable boundary
   |
   |  Objective‑C objects
   v
Obj‑C Framework
   |
   |  NSXPCConnection / NSXPCListener
   v
LaunchAgent Directory + App Instances
```

Key rule:

> **Only C types cross the Node boundary.**

---

## 4. Components

### 4.1 Objective‑C Framework

**Type**: macOS dynamic framework (`.framework` or `.dylib`)

**Responsibilities**:

- Implement all XPC logic
- Wrap NSXPC APIs
- Manage threading and runloops
- Present a C ABI façade

**Internal languages**:

- Objective‑C (primary)
- Swift allowed internally, but not exposed

---

### 4.2 C ABI Shim (Public API)

The **only API visible to Node**.

Rules:

- `extern "C"`
- No Obj‑C types in signatures
- No Swift types
- Explicit ownership rules

---

### 4.3 Node Binding Layer

- Implemented via N‑API addon
- Directly links the native library; if not possible loads the native library via `dlopen`
- Converts C types ↔ JS types
- Manages lifecycle from JS
- Make sure it's thread safe for node event loop

---

## 5. Supported Roles

### 5.1 Client Role

Node can:

- List registered instances
- Connect to a specific instance
- Send a command
- Receive a reply

### 5.2 Service (Instance) Role

Node can:

- Start an XPC service instance
- Register with directory under a name
- Receive commands
- Return responses

Node **does not** implement the directory service.

---

## 6. Public C ABI Specification

### 6.1 Types

```c
typedef void* xpc_client_t;
typedef void* xpc_service_t;
typedef void (*xpc_command_cb)(
    const char* command,
    char** response,
    void* user_data
);
```

---

### 6.2 Client APIs

```c
xpc_client_t xpc_client_create(void);
void xpc_client_destroy(xpc_client_t);

char** xpc_list_instances(
    xpc_client_t,
    int* count
);

char* xpc_send_command(
    xpc_client_t,
    const char* instance,
    const char* command
);
```

Ownership:

- Returned strings allocated by framework
- Caller must free via `xpc_free()`

---

### 6.3 Service APIs

```c
xpc_service_t xpc_service_start(
    const char* instance_name,
    xpc_command_cb callback,
    void* user_data
);

void xpc_service_stop(xpc_service_t);
```

Behavior:

- Starts anonymous XPC listener
- Registers endpoint with directory
- Invokes callback for each command

---

### 6.4 Memory Management

```c
void xpc_free(void* ptr);
void xpc_free_string_array(char** arr, int count);
```

Rules:

- Node **never** calls `free()` directly
- All allocations funnel through framework

---

## 7. Objective‑C Framework Implementation Requirements

### 7.1 Client Implementation

- Wrap `NSXPCConnection(machServiceName:)`
- Implement DirectoryProtocol + InstanceProtocol
- Synchronous C API wraps async XPC using internal queues

### 7.2 Service Implementation

- Create `NSXPCListener.anonymous()`
- Export InstanceProtocol
- Forward incoming calls to C callback

### 7.3 Threading Model

- Dedicated serial dispatch queue per client/service
- Never call into Node from arbitrary threads
- Callbacks executed on framework‑owned threads

---

## 8. Node Binding Requirements

### 8.1 Loading

- Load framework via absolute path
- Validate symbols exist

### 8.2 Callback Bridging

- Map `xpc_command_cb` → JS function
- Ensure callback lifetime exceeds service lifetime

### 8.3 Event Loop Safety

- Use N‑API thread‑safe functions or Bun equivalents
- Never block JS main thread

---

## 9. Error Model

C API returns:

- `NULL` pointers on failure
- Optional error strings (future extension)

Node maps to:

- Exceptions
- Rejected promises

---

## 10. Security Model

- Directory access limited by LaunchAgent (same user)
- No cross‑user access
- No sandbox escape

Optional hardening:

- Code‑signature validation of Node process
- Team‑ID allowlist

---

## 11. Packaging & Distribution

- Framework signed with same Team ID as app
- Node package bundles or references framework
- Versioned C ABI (no breaking changes without bump)

---

## 12. Risks & Tradeoffs (Explicit)

- Node crash brings down XPC logic
- ABI mistakes cause hard crashes
- Harder debugging vs helper IPC
- Tighter coupling between JS and native code

This design is chosen **deliberately**, not by default.

---

## 13. Deliverables

1. Library with Node binding (N‑API)
2. Example client usage
3. Example service usage

---

## 14. Success Criteria

- Node can list instances
- Node can send commands
- Node can host an instance
- No helper process involved
- Clean shutdown without leaks or crashes
