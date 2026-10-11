import Cocoa
// 1024x1024 아이콘 PNG 생성: 둥근 사각형 배경 + 학사모 이모지
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let inset = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2)
let path = NSBezierPath(roundedRect: rect, xRadius: size*0.18, yRadius: size*0.18)
let grad = NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.49, blue: 0.98, alpha: 1),
                      ending: NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.80, alpha: 1))!
grad.draw(in: path, angle: -70)
let para = NSMutableParagraphStyle(); para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size*0.5), .paragraphStyle: para]
let str = NSAttributedString(string: "🎓", attributes: attrs)
let strSize = str.size()
str.draw(in: NSRect(x: 0, y: (size - strSize.height)/2 - size*0.02, width: size, height: strSize.height))
img.unlockFocus()
let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
