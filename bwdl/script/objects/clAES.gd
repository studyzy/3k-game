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
