# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clAES.gd
# 说明：AES 加密工具（自动加载）。用于 mod 数据（bwdl.pck）的解密与校验。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node

var key = "gd secret key!!!"


func _ready() -> void :
	return


func ECB_Encrypted(data: PoolByteArray) -> PoolByteArray:
	var aes = AESContext.new()
	while data.size() % 16 != 0:
		data.append(0)
	aes.start(AESContext.MODE_ECB_ENCRYPT, key.to_utf8())
	var encrypted: PoolByteArray = aes.update(data)
	aes.finish()
	return encrypted
	

func ECB_Decrypted(encrypted: PoolByteArray) -> PoolByteArray:
	if encrypted.empty():
		return PoolByteArray([])
	var aes = AESContext.new()
	
	aes.start(AESContext.MODE_ECB_DECRYPT, key.to_utf8())
	var decrypted: PoolByteArray = aes.update(encrypted)
	aes.finish()
	return decrypted
