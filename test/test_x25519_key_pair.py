from cryptography.hazmat.primitives.asymmetric import x25519
from cryptography.hazmat.primitives import serialization

# ==============================================================================
# 請在下方直接填入您的金鑰字串（支援 16 進位 hex 字串，大小寫皆可）
# ==============================================================================
PRIVATE_KEY_STR = "4a0f8b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a"  # 範例私鑰
PUBLIC_KEY_STR  = "8520f0098930a754748b7ddcb43ef75a0db6fc4387e1a41d4cf01831b5a4968d"  # 範例公鑰
# ==============================================================================

def validate_x25519_strings(priv_str, pub_str):
    try:
        # 1. 將 Hex 字串轉換為 bytes
        priv_bytes = bytes.fromhex(priv_str.strip())
        pub_bytes = bytes.fromhex(pub_str.strip())

        # 2. 檢查長度是否為 32 bytes (256 bits)
        if len(priv_bytes) != 32 or len(pub_bytes) != 32:
            print("❌ 驗證失敗：X25519 金鑰長度必須為 32 bytes (64 個 Hex 字元)。")
            return False

        # 3. 從私鑰衍生出正確的公鑰
        private_key = x25519.X25519PrivateKey.from_private_bytes(priv_bytes)
        derived_public_key = private_key.public_key()

        # 4. 將衍生的公鑰轉回 bytes 進行比對
        derived_pub_bytes = derived_public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )

        # 5. 比對結果
        if derived_pub_bytes == pub_bytes:
            print("✅ 驗證成功：這組金鑰配對正確！")
            return True
        else:
            print("❌ 驗證失敗：此私鑰所衍生出的公鑰與輸入的公鑰不符。")
            print(f"👉 該私鑰正確的公鑰應為: {derived_pub_bytes.hex()}")
            return False

    except ValueError:
        print("❌ 錯誤：請確認輸入的金鑰字串是否為正確的 Hex 格式（只能包含 0-9 與 a-f）。")
        return False
    except Exception as e:
        print(f"❌ 發生未知錯誤: {e}")
        return False

if __name__ == "__main__":
    validate_x25519_strings(PRIVATE_KEY_STR, PUBLIC_KEY_STR)

