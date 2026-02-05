# The MTU (Maximum Transmission Unit) Problem in Nested OpenStack

## 1. The Symptom
*   **What happens:** VMs boot successfully, and you can ping them. However, `apt-get install` hangs indefinitely at 0%, or SSH connects but freezes when listing large directories or files.
*   **The Error:** Often manifests as "Connection timed out" or "Connection refused" (if the boot script is blocked waiting for network).

## 2. The Cause: "Packet Too Big"
In a standard network, the maximum packet size (MTU) is **1500 bytes**.

In your nested setup (Laptop -> VirtualBox -> DevStack -> VM), "Encapsulation" occurs:
1.  **Your VM** sends a standard 1500-byte packet.
2.  **OpenStack (DevStack)** wraps this packet inside a **VXLAN Tunnel** to send it across its virtual network.
    *   *VXLAN overhead:* ~50 bytes.
    *   *New Packet Size:* **1550 bytes**.
3.  **VirtualBox (The Outer Layer)** has a physical interface MTU of **1500 bytes**.
    *   It sees a 1550-byte packet coming from DevStack.
    *   **Result:** It **DROPS** the packet because it's too large to transmit.

## 3. Why it's Tricky
*   **Small Packets Work:** Ping (64 bytes) and the initial SSH Handshake fits easily inside the 1500 limit. This makes the server *look* alive.
*   **Large Packets Fail:** As soon as you try to download a file (`apt-get`) or send a large screen of text, the packet hits the 1500 limit and vanishes.

## 4. The Solution: Lower the MTU
We tell the inner VM to send smaller packets (e.g., **1400 bytes**) from the start.

*   **Logic:** 1400 bytes (Data) + 50 bytes (VXLAN Header) = **1450 bytes**.
*   **Result:** 1450 is less than the 1500 limit of VirtualBox, so the packet passes through successfully.

## 5. Implementation
Add this command to the very top of any `user_data` or boot script:
```bash
# Force MTU to 1400 on the main interface (eth0 or ens3)
ip link set dev eth0 mtu 1400 || ip link set dev ens3 mtu 1400
```
