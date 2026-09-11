import AppKit
import ImageIO
import UniformTypeIdentifiers
let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let c = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:cs,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
c.setFillColor(CGColor(red:0.15,green:0.23,blue:0.17,alpha:1)); c.fill(CGRect(x:0,y:0,width:size,height:size))
c.setStrokeColor(CGColor(red:0.91,green:0.93,blue:0.81,alpha:1)); c.setLineWidth(30); c.strokeEllipse(in:CGRect(x:155,y:150,width:714,height:714))
c.setFillColor(CGColor(red:0.91,green:0.93,blue:0.81,alpha:1))
c.move(to:CGPoint(x:510,y:330)); c.addCurve(to:CGPoint(x:330,y:695),control1:CGPoint(x:205,y:345),control2:CGPoint(x:255,y:600)); c.addCurve(to:CGPoint(x:510,y:330),control1:CGPoint(x:570,y:695),control2:CGPoint(x:588,y:460)); c.fillPath()
c.setFillColor(CGColor(red:0.67,green:0.75,blue:0.48,alpha:1))
c.move(to:CGPoint(x:515,y:410)); c.addCurve(to:CGPoint(x:743,y:670),control1:CGPoint(x:450,y:680),control2:CGPoint(x:620,y:730)); c.addCurve(to:CGPoint(x:515,y:410),control1:CGPoint(x:765,y:440),control2:CGPoint(x:590,y:380)); c.fillPath()
c.setStrokeColor(CGColor(red:0.91,green:0.93,blue:0.81,alpha:1)); c.setLineWidth(22); c.setLineCap(.round); c.move(to:CGPoint(x:512,y:289)); c.addCurve(to:CGPoint(x:507,y:582),control1:CGPoint(x:540,y:380),control2:CGPoint(x:510,y:490)); c.strokePath()
let target = URL(fileURLWithPath:CommandLine.arguments[1])
let out = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(out,c.makeImage()!,nil); CGImageDestinationFinalize(out)
