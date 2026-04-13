import SwiftUI

struct ScannerOverlayView: View {
    let isProcessing: Bool

    var body: some View {
        ZStack {
            // Dimmed border
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: 280, height: 180)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            // Guide frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 280, height: 180)

            // Corner markers
            cornerMarkers

            // Instructions / processing indicator
            VStack {
                Spacer()
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                        .padding(VSpacing.md)
                        .background(.ultraThinMaterial)
                        .cornerRadius(VSpacing.cornerRadiusMD)
                } else {
                    Text(String(localized: "Align receipt within the frame"))
                        .font(VTypography.caption1)
                        .foregroundColor(.white)
                        .padding(.horizontal, VSpacing.md)
                        .padding(.vertical, VSpacing.sm)
                        .background(.ultraThinMaterial)
                        .cornerRadius(VSpacing.cornerRadiusMD)
                }
            }
            .padding(.bottom, VSpacing.xxxl)
        }
    }

    private var cornerMarkers: some View {
        ZStack {
            ForEach(Corner.allCases, id: \.self) { corner in
                CornerMarker(corner: corner)
            }
        }
        .frame(width: 280, height: 180)
    }
}

private enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct CornerMarker: View {
    let corner: Corner
    private let size: CGFloat = 20
    private let thickness: CGFloat = 3

    var body: some View {
        ZStack {
            Rectangle()
                .fill(VColors.primary)
                .frame(width: size, height: thickness)
                .offset(x: horizontalOffset, y: 0)

            Rectangle()
                .fill(VColors.primary)
                .frame(width: thickness, height: size)
                .offset(x: 0, y: verticalOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(thickness / 2)
    }

    private var horizontalOffset: CGFloat {
        switch corner {
        case .topLeft, .bottomLeft: return size / 2 - 1
        case .topRight, .bottomRight: return -(size / 2 - 1)
        }
    }

    private var verticalOffset: CGFloat {
        switch corner {
        case .topLeft, .topRight: return size / 2 - 1
        case .bottomLeft, .bottomRight: return -(size / 2 - 1)
        }
    }

    private var alignment: Alignment {
        switch corner {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        ScannerOverlayView(isProcessing: false)
    }
}
