import SwiftUI

enum Palette {
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let ink = Color(red: 0.15, green: 0.23, blue: 0.17)
    static let green = Color(red: 0.25, green: 0.38, blue: 0.22)
    static let sage = Color(red: 0.86, green: 0.89, blue: 0.77)
    static let orange = Color(red: 0.83, green: 0.31, blue: 0.16)
    static let muted = Color(red: 0.43, green: 0.46, blue: 0.40)
    static let line = Color(red: 0.86, green: 0.86, blue: 0.81)
}
extension View {
    func savorCard(_ color: Color = .white) -> some View { padding(20).background(color, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.line.opacity(0.6), lineWidth: 1)) }
    func pageStyle() -> some View { background(Palette.cream.ignoresSafeArea()).foregroundStyle(Palette.ink).tint(Palette.green) }
}
struct Eyebrow: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Palette.muted) }
}
struct ActionButton: View {
    var title: String
    var symbol = "arrow.right"
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) { HStack { Text(title).font(.system(size: 16, weight: .semibold)); Spacer(); Image(systemName: symbol) }.padding(.horizontal, 22).frame(minHeight: 56).foregroundStyle(.white).background(disabled ? Palette.muted : Palette.ink, in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain).disabled(disabled)
    }
}
struct Pill: View {
    var text: String
    var symbol: String? = nil
    var orange = false
    var body: some View { HStack(spacing: 5) { if let symbol { Image(systemName: symbol) }; Text(text) }.font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 7).background(orange ? Palette.orange.opacity(0.12) : Palette.sage.opacity(0.6), in: Capsule()).foregroundStyle(orange ? Palette.orange : Palette.ink) }
}
struct BowlArt: View {
    var variant = 0
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 240
            ctx.translateBy(x: (size.width - 240*s)/2, y: (size.height - 240*s)/2); ctx.scaleBy(x: s, y: s)
            ctx.fill(Path(ellipseIn: CGRect(x: 23, y: 35, width: 198, height: 192)), with: .color(Palette.ink.opacity(0.08)))
            ctx.fill(Path(ellipseIn: CGRect(x: 14, y: 20, width: 210, height: 210)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: 25, y: 31, width: 188, height: 188)), with: .color(Palette.line), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: 39, y: 45, width: 160, height: 160)), with: .color(Color(red: 0.9, green: 0.84, blue: 0.62)))
            for i in 0..<20 {
                let x = 59.0 + Double((i * 31 + variant * 11) % 119), y = 67.0 + Double((i * 47) % 105)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 11, height: 6)), with: .color(Color(red: 0.99, green: 0.95, blue: 0.81)))
            }
            for i in 0..<9 {
                var leaf = Path(); let x = 56.0 + Double(i%3)*29, y = 60.0 + Double(i/3)*27
                leaf.move(to: CGPoint(x:x,y:y)); leaf.addQuadCurve(to:CGPoint(x:x+29,y:y+30),control:CGPoint(x:x-10,y:y+35)); leaf.addQuadCurve(to:CGPoint(x:x,y:y),control:CGPoint(x:x+42,y:y-9))
                ctx.fill(leaf, with:.color(i%2 == 0 ? Palette.green : Color(red:0.39,green:0.53,blue:0.27)))
            }
            for (x,y) in [(133.0,73.0),(151,113),(119,151),(80,157)] {
                ctx.fill(Path(ellipseIn:CGRect(x:x,y:y,width:29,height:28)),with:.color(Palette.orange))
                ctx.stroke(Path(ellipseIn:CGRect(x:x+6,y:y+6,width:17,height:16)),with:.color(Color.white.opacity(0.45)),lineWidth:1.5)
            }
            for i in 0..<11 {
                ctx.fill(Path(ellipseIn:CGRect(x:137+Double(i%3)*13,y:151+Double(i/3)*10,width:10,height:9)),with:.color(Color(red:0.87,green:0.67,blue:0.34)))
            }
            ctx.fill(Path(ellipseIn:CGRect(x:160,y:43,width:41,height:41)),with:.color(Color(red:0.96,green:0.84,blue:0.32)))
            ctx.fill(Path(ellipseIn:CGRect(x:166,y:49,width:29,height:29)),with:.color(Color(red:0.99,green:0.93,blue:0.66)))
        }.accessibilityHidden(true)
    }
}
struct EmptyCard: View {
    let symbol: String; let title: String; let message: String
    var body: some View { VStack(spacing: 14) { Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(Palette.green).padding(15).background(Palette.sage, in: Circle()); Text(title).font(.system(size: 25, design: .serif)); Text(message).font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 28).savorCard() }
}
