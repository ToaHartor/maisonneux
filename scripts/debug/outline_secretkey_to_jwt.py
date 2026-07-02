import os
import json
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding as sym_padding

SECRET_KEY_HEX = "SECRET_KEY"
key = bytes.fromhex(SECRET_KEY_HEX)

# 1. Generate random secret & JSON-serialize it (matches Outline's internal behavior)
plaintext_str = json.dumps(os.urandom(32).hex())
plaintext = plaintext_str.encode("utf-8")

# 2. Generate IV
iv = os.urandom(16)

# 3. PKCS7 padding
padder = sym_padding.PKCS7(128).padder()
padded_data = padder.update(plaintext) + padder.finalize()

# 4. Encrypt
cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
encryptor = cipher.encryptor()
ciphertext = encryptor.update(padded_data) + encryptor.finalize()

# 5. Combine IV + Ciphertext
encrypted_blob = iv + ciphertext
print(encrypted_blob.hex())

# 6. Update the jwtSecret in the outline database update users set "jwtSecret" = decode('encrypted_blob', 'hex') where email = 'admin@example';
