class QrCodeSvg
  def self.generate(data)
    qr = RQRCode::QRCode.new(data)
    qr.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true
    )
  end
end
