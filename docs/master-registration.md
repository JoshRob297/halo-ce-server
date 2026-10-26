# Master Server Registration Guide

This guide details the procedure for registering a dedicated server with the official OpenCE Master Server (`master.opencommunityedition.com`).

Starting with OpenCE Build 289, dedicated servers displayed under the in-game **DEDICATED** browser tab require cryptographic authentication using an Ed25519 keypair registered with the official registry bot. Unauthenticated servers remain discoverable via public P2P signaling brokers under the general browser, but will not appear in the verified DEDICATED category without completing this verification workflow.

---

## 1. Cryptographic Key Generation (`--keygen`)

The OpenCE engine utilizes asymmetric Ed25519 signatures for server identity verification. Before applying for registration, generate a unique publisher keypair on your host machine.

### Execution

Run the `halo` binary from your server installation directory using the `--keygen` argument:

```bash
./halo --keygen
```

### Key Management and Security Policies

1. **File Generation**: The engine generates a 64-byte key file named `publisher.key` in the current working directory, alongside the corresponding public key in hexadecimal format.
2. **Permissions**: Set strict filesystem permissions immediately to avoid private key compromise:
   ```bash
   chmod 600 publisher.key
   ```
3. **OPSEC Directives**:
   - Never commit `publisher.key` to version control repositories.
   - Never expose `publisher.key` through public directories, web dashboards, or container logs.
   - Restrict read access strictly to the system user executing the server process.

---

## 2. Discord Master Server Application (`/apply`)

Server registration is coordinated through the OpenCE Master Server operations bot hosted in the official Discord guild.

### Step-by-Step Procedure

1. Join the official OpenCE Community Discord server.
2. Navigate to the `#master-server-registration` or dedicated bot interaction channel.
3. Execute the `/apply` slash command:
   ```text
   /apply public_key:<YOUR_HEX_PUBLIC_KEY> server_name:<YOUR_SERVER_NAME>
   ```
4. The Master Server bot validates the public key format and issues a cryptographic challenge string called a **nonce** (a high-entropy, single-use random hexadecimal string).
5. Copy the exact nonce string provided in the bot's response. The challenge expires after a fixed time window (typically 15 minutes).

---

## 3. Cryptographic Proof of Possession (`--sign`)

To prove ownership of the private key matching the submitted public key, sign the challenge nonce with the `halo` engine CLI.

### Signing the Challenge

Execute the `halo` binary using the `--sign` flag followed by the exact nonce string received from the bot:

```bash
./halo --sign "<nonce>"
```

### Response Output

The binary reads `publisher.key` from the working directory, computes the Ed25519 signature over the challenge payload, and prints the resulting signature to standard output:

```text
nonce:     a8f9c1d2e3b4...
signature: 5f8a9b2c...3d1e
```

### Completing the Handshake

1. Return to the registration channel on Discord.
2. Submit the signature proof using the verification command prompted by the bot:
   ```text
   /verify nonce:<nonce> signature:<SIGNATURE_HEX>
   ```
3. Once the signature is validated against the registered public key, the bot issues confirmation:
   ```text
   Server identity verified. Publisher authorized for official DEDICATED listings.
   ```

---

## 4. Server Configuration and Master Listing Verification

After registration approval, configure your dedicated server configuration file to declare geographic location and establish communications with the master server.

### Configuration (`server/config.toml`)

Open `server/config.toml` (or pass the equivalent environment variables) and set the identity parameters:

```toml
[network]
online = true
host_public = true
tunnel_port = 2302

# Server Region Identifier
# Displayed in the Server Browser ping/region column.
# Valid options: "eu", "na-e", "na-w", "sa", "ap-e", "ap-s", "af"
region = "eu"
```

Environment variable alternative:
```bash
export HALO_SERVER_REGION="eu"
export HALO_NET_ONLINE="true"
export HALO_NET_HOST_PUBLIC="true"
```

### Network Requirements

The Master Server performs an active health probe against your host to verify client reachability before adding the node to the public directory:

- Ensure UDP port `2302` (or the configured `network.tunnel_port`) is open and forwarded through your gateway/firewall.
- Confirm stateful egress connectivity to HTTPS port `443` on `master.opencommunityedition.com`.

### Verifying the Listing

1. Start your dedicated server daemon:
   ```bash
   ./halo
   ```
2. Inspect the startup log output for the master publication handshake:
   ```text
   server_master: publishing identity to master.opencommunityedition.com...
   server_master: published to master.opencommunityedition.com (200 OK)
   ```
3. Launch the OpenCE game client (Build 289 or newer).
4. Navigate to **Multiplayer** > **Internet**.
5. Switch to the **DEDICATED** tab.
6. Confirm your server appears in the list with the configured name, player slots, low latency indicators, and the assigned region label (e.g., `EU`).
