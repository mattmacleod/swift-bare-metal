@_silgen_name("kmain") public func kmain() {
  clearScreen()
  writeMessage()
}

private func writeMessage() {
  let ptr = getScreenPointer()

  ptr[1] = 0x0F53
  ptr[2] = 0x0F48
  ptr[3] = 0x0F41
  ptr[4] = 0x0F4b
  ptr[5] = 0x0F45
  ptr[6] = 0x0F20
  ptr[7] = 0x0F49
  ptr[8] = 0x0F54
  ptr[9] = 0x0F20
  ptr[10] = 0x0F4f
  ptr[11] = 0x0F46
  ptr[12] = 0x0F46
}

private func clearScreen() {
  let ptr = getScreenPointer()

  var i = 0
  while i < 80 * 25 {
    ptr[i] = 0x0F00 | 0x00;
    i = i + 1
  }
}

private func getScreenPointer() -> UnsafeMutablePointer<UInt16> {
  return UnsafeMutablePointer<UInt16>(bitPattern: 0xB8000)!
}
