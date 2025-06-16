import UIKit

open class EventView: UIView {
    public var descriptor: EventDescriptor?
    public var color = SystemColors.label
    public var lineColor = SystemColors.label
    
    public var contentHeight: Double {
        textView.frame.height
    }
    
    public private(set) lazy var textView: UITextView = {
        let view = UITextView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.clipsToBounds = true
        return view
    }()
    
    /// Resize Handle views showing up when editing the event.
    /// The top handle has a tag of `0` and the bottom has a tag of `1`
    public private(set) lazy var eventResizeHandles = [EventResizeHandleView(), EventResizeHandleView()]
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    private func configure() {
        clipsToBounds = false
        color = tintColor
        lineColor = tintColor
        addSubview(textView)
        
        for (idx, handle) in eventResizeHandles.enumerated() {
            handle.tag = idx
            addSubview(handle)
        }
    }
    
    public func updateWithDescriptor(event: EventDescriptor) {
        if let attributedText = event.attributedText {
            textView.attributedText = attributedText
            textView.setNeedsLayout()
        } else {
            textView.text = event.text
            textView.textColor = event.textColor
            textView.font = event.font
        }
        if let lineBreakMode = event.lineBreakMode {
            textView.textContainer.lineBreakMode = lineBreakMode
        }
        descriptor = event
        backgroundColor = .clear
        layer.backgroundColor = event.backgroundColor.cgColor
        
        let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
        if leftToRight {
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        } else {
            layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
        layer.cornerRadius = 5
        
        color = event.color
        lineColor = event.lineColor ?? event.color
        eventResizeHandles.forEach{
            $0.borderColor = event.color
            $0.isHidden = event.editedEvent == nil
        }
        drawsShadow = event.editedEvent != nil
        setNeedsDisplay()
        setNeedsLayout()
    }
    
    public func animateCreation() {
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        func scaleAnimation() {
            transform = .identity
        }
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       usingSpringWithDamping: 0.2,
                       initialSpringVelocity: 10,
                       options: [],
                       animations: scaleAnimation,
                       completion: nil)
    }
    
    /**
     Custom implementation of the hitTest method is needed for the tap gesture recognizers
     located in the ResizeHandleView to work.
     Since the ResizeHandleView could be outside of the EventView's bounds, the touches to the ResizeHandleView
     are ignored.
     In the custom implementation the method is recursively invoked for all of the subviews,
     regardless of their position in relation to the Timeline's bounds.
     */
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for resizeHandle in eventResizeHandles {
            if let subSubView = resizeHandle.hitTest(convert(point, to: resizeHandle), with: event) {
                return subSubView
            }
        }
        return super.hitTest(point, with: event)
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        context.saveGState()
        
        let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
        let lineWidth: CGFloat = 3.0
        let cornerRadius: CGFloat = 1.5 // Half of line width for rounded ends
        
        // Create the line rectangle pinned to the appropriate edge
        let lineRect: CGRect
        if leftToRight {
            // Pin to left edge
            lineRect = CGRect(x: 0, y: 0, width: lineWidth, height: bounds.height)
        } else {
            // Pin to right edge  
            lineRect = CGRect(x: bounds.width - lineWidth, y: 0, width: lineWidth, height: bounds.height)
        }
        
        // Create rounded rectangle path with corners only on the pinned edge
        let linePath = UIBezierPath()
        if leftToRight {
            // For left edge: round left corners only
            linePath.move(to: CGPoint(x: lineRect.minX + cornerRadius, y: lineRect.minY))
            linePath.addLine(to: CGPoint(x: lineRect.maxX, y: lineRect.minY))
            linePath.addLine(to: CGPoint(x: lineRect.maxX, y: lineRect.maxY))
            linePath.addLine(to: CGPoint(x: lineRect.minX + cornerRadius, y: lineRect.maxY))
            linePath.addArc(withCenter: CGPoint(x: lineRect.minX + cornerRadius, y: lineRect.maxY - cornerRadius), 
                           radius: cornerRadius, 
                           startAngle: .pi/2, 
                           endAngle: .pi, 
                           clockwise: true)
            linePath.addLine(to: CGPoint(x: lineRect.minX, y: lineRect.minY + cornerRadius))
            linePath.addArc(withCenter: CGPoint(x: lineRect.minX + cornerRadius, y: lineRect.minY + cornerRadius), 
                           radius: cornerRadius, 
                           startAngle: .pi, 
                           endAngle: 3 * .pi/2, 
                           clockwise: true)
        } else {
            // For right edge: round right corners only
            linePath.move(to: CGPoint(x: lineRect.minX, y: lineRect.minY))
            linePath.addLine(to: CGPoint(x: lineRect.maxX - cornerRadius, y: lineRect.minY))
            linePath.addArc(withCenter: CGPoint(x: lineRect.maxX - cornerRadius, y: lineRect.minY + cornerRadius), 
                           radius: cornerRadius, 
                           startAngle: 3 * .pi/2, 
                           endAngle: 0, 
                           clockwise: true)
            linePath.addLine(to: CGPoint(x: lineRect.maxX, y: lineRect.maxY - cornerRadius))
            linePath.addArc(withCenter: CGPoint(x: lineRect.maxX - cornerRadius, y: lineRect.maxY - cornerRadius), 
                           radius: cornerRadius, 
                           startAngle: 0, 
                           endAngle: .pi/2, 
                           clockwise: true)
            linePath.addLine(to: CGPoint(x: lineRect.minX, y: lineRect.maxY))
            linePath.addLine(to: CGPoint(x: lineRect.minX, y: lineRect.minY))
        }
        linePath.close()
        
        // Fill the path with the line color
        context.setFillColor(lineColor.cgColor)
        context.addPath(linePath.cgPath)
        context.fillPath()
        
        context.restoreGState()
    }
    
    private var drawsShadow = false
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = {
            if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
                return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width - 3, height: bounds.height)
            } else {
                return CGRect(x: bounds.minX + 8, y: bounds.minY, width: bounds.width - 6, height: bounds.height)
            }
        }()
        if frame.minY < 0 {
            var textFrame = textView.frame;
            textFrame.origin.y = frame.minY * -1;
            textFrame.size.height += frame.minY;
            textView.frame = textFrame;
        }
        let first = eventResizeHandles.first
        let last = eventResizeHandles.last
        let radius: Double = 40
        let yPad: Double =  -radius / 2
        let width = bounds.width
        let height = bounds.height
        let size = CGSize(width: radius, height: radius)
        first?.frame = CGRect(origin: CGPoint(x: width - radius - layoutMargins.right, y: yPad),
                              size: size)
        last?.frame = CGRect(origin: CGPoint(x: layoutMargins.left, y: height - yPad - radius),
                             size: size)
        
        if drawsShadow {
            applySketchShadow(alpha: 0.13,
                              blur: 10)
        }
    }
    
    private func applySketchShadow(
        color: UIColor = .black,
        alpha: Float = 0.5,
        x: Double = 0,
        y: Double = 2,
        blur: Double = 4,
        spread: Double = 0)
    {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = alpha
        layer.shadowOffset = CGSize(width: x, height: y)
        layer.shadowRadius = blur / 2.0
        if spread == 0 {
            layer.shadowPath = nil
        } else {
            let dx = -spread
            let rect = bounds.insetBy(dx: dx, dy: dx)
            layer.shadowPath = UIBezierPath(rect: rect).cgPath
        }
    }
}
