﻿unit KM_Controls;
{$I KaM_Remake.inc}
interface
uses
  Classes,
  Controls,
  Generics.Collections,
  KromOGLUtils,
  KM_RenderUI, KM_Pics, KM_Minimap, KM_Viewport,
  KM_ResFonts, KM_ResTypes,
  KM_CommonClasses, KM_CommonTypes, KM_Points, KM_Defaults;


type
  TNotifyEventShift = procedure(Sender: TObject; Shift: TShiftState) of object;
  TNotifyEventMB = procedure(Sender: TObject; AButton: TMouseButton) of object;
  TNotifyEventMW = procedure(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean) of object;
  TKMMouseMoveEvent = procedure(Sender: TObject; X,Y: Integer; Shift: TShiftState) of object;
  TKMMouseUpDownEvent = procedure(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton) of object;
  TNotifyEventKey = procedure(Sender: TObject; Key: Word) of object;
  TNotifyEventKeyFunc = function(Sender: TObject; Key: Word): Boolean of object;
  TNotifyEventKeyShift = procedure(Key: Word; Shift: TShiftState) of object;
  TNotifyEventKeyShiftFunc = function(Sender: TObject; Key: Word; Shift: TShiftState): Boolean of object;
  TNotifyEventXY = procedure(Sender: TObject; X, Y: Integer) of object;
  TNotifyEvenClickHold = procedure(Sender: TObject; AButton: TMouseButton; var aHandled: Boolean) of object;
  TPointEventShiftFunc = function (Sender: TObject; Shift: TShiftState; const X,Y: Integer): Boolean of object;

  TKMControlState = (csDown, csFocus, csOver);
  TKMControlStateSet = set of TKMControlState;

  TKMHintKind = (hkControl, // Rendered above control
                 hkStatic,  // 'Classic' hint: rendered in the game / mapEd at the bottom left of the play-area
                 hkTextNotFit); // Hint to show text, when it could not fit in the control, f.e. in the Lists and ColumnBoxes

  TKMControl = class;
  TKMPanel = class;

  { TKMMasterControl }
  TKMMasterControl = class
  private
    fMasterPanel: TKMPanel; //Parentmost control (TKMPanel with all its childs)
    fCtrlDown: TKMControl; //Control that was pressed Down
    fCtrlFocus: TKMControl; //Control which has input Focus
    fCtrlOver: TKMControl; //Control which has cursor Over it
    fCtrlUp: TKMControl; //Control above which cursor was released

    fControlIDCounter: Integer;
    fMaxPaintLayer: Integer;
    fCurrentPaintLayer: Integer;

    fMouseMoveSubsList: TList<TKMMouseMoveEvent>;
    fMouseDownSubsList: TList<TKMMouseUpDownEvent>;
    fMouseUpSubsList: TList<TKMMouseUpDownEvent>;

    function IsCtrlCovered(aCtrl: TKMControl): Boolean;
    procedure SetCtrlDown(aCtrl: TKMControl);
    procedure SetCtrlFocus(aCtrl: TKMControl);
    procedure SetCtrlOver(aCtrl: TKMControl);
    procedure SetCtrlUp(aCtrl: TKMControl);

    function GetNextCtrlID: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    property MasterPanel: TKMPanel read fMasterPanel;
    function IsFocusAllowed(aCtrl: TKMControl): Boolean;
    function IsAutoFocusAllowed(aCtrl: TKMControl): Boolean;
    procedure UpdateFocus(aSender: TKMControl);

    property CtrlDown: TKMControl read fCtrlDown write SetCtrlDown;
    property CtrlFocus: TKMControl read fCtrlFocus write SetCtrlFocus;
    property CtrlOver: TKMControl read fCtrlOver write SetCtrlOver;
    property CtrlUp: TKMControl read fCtrlUp write SetCtrlUp;

    procedure AddMouseMoveCtrlSub(const aMouseMoveEvent: TKMMouseMoveEvent);
    procedure AddMouseDownCtrlSub(const aMouseDownEvent: TKMMouseUpDownEvent);
    procedure AddMouseUpCtrlSub(const aMouseUpEvent: TKMMouseUpDownEvent);

    function HitControl(X,Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): TKMControl;

    function KeyDown    (Key: Word; Shift: TShiftState): Boolean;
    procedure KeyPress  (Key: Char);
    function KeyUp      (Key: Word; Shift: TShiftState): Boolean;
    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    procedure MouseMove (X,Y: Integer; Shift: TShiftState);
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    procedure MouseWheel(X,Y: Integer; WheelSteps: Integer; var aHandled: Boolean);

    procedure Paint;

    procedure SaveToFile(const aFileName: UnicodeString);

    procedure UpdateState(aGlobalTickCount: Cardinal);
  end;


  {Base class for all TKM elements}
  TKMControl = class
//  type
//    TKMKeyPressKind = (kpkDown, kpkPress);
//    TKMKeyPress = record
//      Time: Int64;
////      Key: Word;
//      C: Char;
//      Kind: TKMKeyPressKind;
//      function ToString: string;
//    end;
  private
//    fKeyPressList: TList<TKMKeyPress>;

    fParent: TKMPanel;
    fAnchors: TKMAnchorsSet;

    //Left and Top are floating-point to allow to precisely store controls position
    //when Anchors [] are used. Cos that means that control must be centered
    //even if the Parent resized by 1px. Otherwise error quickly accumulates on
    //multiple 1px resizes
    //Everywhere else Top and Left are accessed through Get/Set and treated as Integers
    fLeft: Single;
    fTop: Single;
    fWidth: Integer;
    fHeight: Integer;

    fFitInParent: Boolean; // Do we force to fit into parent width / height. Check TKMPanel.SetHeight / SetWidth for details
    fBaseWidth: Integer; // initial width / height used to restore control sizes when fFitInParent property is set
    fBaseHeight: Integer;

    fEnabled: Boolean;
    fEnabledVisually: Boolean;
    fVisible: Boolean;
    fFocusable: Boolean; //Can this control have focus (e.g. TKMEdit sets this true)
    fControlIndex: Integer; //Index number of this control in his Parent's (TKMPanel) collection
    fID: Integer; //Control global ID
    fHint: UnicodeString; //Text that shows up when cursor is over that control, mainly for Buttons
    fHintBackColor: TKMColor4f; //Hint background color
    fMouseWheelStep: Integer;

    fPaintLayer: Integer;

    fTimeOfLastClick: Cardinal; //Required to handle double-clicks

    fClickHoldMode: Boolean;
    fClickHoldHandled: Boolean;
    fTimeOfLastMouseDown: Cardinal;
    fLastMouseDownButton: TMouseButton;
    fLastClickPos: TKMPoint;

    fOnClick: TNotifyEvent;
    fOnClickShift: TNotifyEventShift;
    fOnClickRight: TPointEvent;
    fOnClickHold: TNotifyEvenClickHold;
    fOnDoubleClick: TNotifyEvent;
    fOnMouseWheel: TNotifyEventMW;
    fOnFocus: TBooleanObjEvent;
    fOnChangeVisibility: TBooleanObjEvent;
    fOnChangeEnableStatus: TBooleanObjEvent;
    fOnKeyDown: TNotifyEventKeyShiftFunc;
    fOnKeyUp: TNotifyEventKeyShiftFunc;

    fOnWidthChange: TObjectIntegerEvent;
    fOnHeightChange: TObjectIntegerEvent;
    fOnSizeSet: TNotifyEvent;
    fOnPositionSet: TNotifyEvent;

    fIsHitTestUseDrawRect: Boolean; //Should we use DrawRect for hitTest, or AbsPositions?

    function PaintingBaseLayer: Boolean;

    function GetAbsLeft: Integer;
    function GetAbsTop: Integer;
    function GetAbsRight: Integer;
    function GetAbsBottom: Integer;

    function GetLeft: Integer;
    function GetTop: Integer;
    function GetRight: Integer;
    function GetBottom: Integer;
    function GetHeight: Integer;
    function GetWidth: Integer;
    function GetCenter: TKMPoint;

    //Let the control know that it was clicked to do its internal magic
    procedure DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;

    function GetVisible: Boolean;
    procedure SetAbsLeft(aValue: Integer);
    procedure SetAbsTop(aValue: Integer);
    procedure SetTopF(aValue: Single);
    procedure SetLeftF(aValue: Single);
    function GetControlRect: TKMRect;
    function GetControlAbsRect: TKMRect;
    function GetIsFocused: Boolean;
    function GetIsClickable: Boolean;

    procedure ResetClickHoldMode;

    procedure DebugKeyDown(Key: Word; Shift: TShiftState);
    procedure SetFocusable(const aValue: Boolean);
    function GetMasterPanel: TKMPanel;
  protected
    procedure SetLeft(aValue: Integer); virtual;
    procedure SetTop(aValue: Integer); virtual;
    procedure SetHeight(aValue: Integer); virtual;
    procedure SetWidth(aValue: Integer); virtual;

    function GetAbsDrawLeft: Integer; virtual;
    function GetAbsDrawTop: Integer; virtual;
    function GetAbsDrawRight: Integer; virtual;
    function GetAbsDrawBottom: Integer; virtual;

    property AbsDrawLeft: Integer read GetAbsDrawLeft;
    property AbsDrawRight: Integer read GetAbsDrawRight;
    property AbsDrawTop: Integer read GetAbsDrawTop;
    property AbsDrawBottom: Integer read GetAbsDrawBottom;

    function GetDrawRect: TKMRect; virtual;

    procedure SetVisible(aValue: Boolean); virtual;
    procedure SetEnabled(aValue: Boolean); virtual;
    procedure SetAnchors(aValue: TKMAnchorsSet); virtual;
    function GetIsPainted: Boolean; virtual;
    function GetSelfAbsLeft: Integer; virtual;
    function GetSelfAbsTop: Integer; virtual;
    function GetSelfHeight: Integer; virtual;
    function GetSelfWidth: Integer; virtual;
    procedure UpdateVisibility; virtual;
    procedure UpdateEnableStatus; virtual;
//    procedure ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;
//    procedure ControlMouseUp(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;
    procedure FocusChanged(aFocused: Boolean); virtual;
    procedure DoClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean); virtual;
    function DoHandleMouseWheelByDefault: Boolean; virtual;

    function GetHint: UnicodeString; virtual;
    function GetHintKind: TKMHintKind; virtual;
    function GetHintFont: TKMFont; virtual;
    function IsHintSelected: Boolean; virtual;
    function GetHintBackColor: TKMColor4f; virtual;
    function GetHintTextColor: TColor4; virtual;
    function GetHintBackRect: TKMRect; virtual;
    function GetHintTextOffset: TKMPoint; virtual;
    procedure SetHint(const aHint: UnicodeString); virtual;
    procedure SetHintBackColor(const aValue: TKMColor4f); virtual;

    procedure SetPaintLayer(aPaintLayer: Integer);

    function CanFocusNext: Boolean; virtual;
  public
    Hitable: Boolean; //Can this control be hit with the cursor?

    AutoFocusable: Boolean; //Can we focus on this element automatically (f.e. if set to False we will able to Focus only by manual mouse click)
    HandleMouseWheelByDefault: Boolean; //Do control handle MW by default? Usually it is
    CanChangeEnable: Boolean; //Enable state could be changed

    State: TKMControlStateSet; //Each control has it localy to avoid quering Collection on each Render
    Scale: Single; //Child controls position is scaled

    Tag: Integer; //Some tag which can be used for various needs
    Tag2: Integer; //Some tag which can be used for various needs

    DebugHighlight: Boolean;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLayer: Integer = 0);
    destructor Destroy; override;
    function HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): Boolean; virtual;

    property Parent: TKMPanel read fParent;
    property MasterPanel: TKMPanel read GetMasterPanel;

    property AbsLeft: Integer read GetAbsLeft write SetAbsLeft;
    property AbsRight: Integer read GetAbsRight;
    property AbsTop: Integer read GetAbsTop write SetAbsTop;
    property AbsBottom: Integer read GetAbsBottom;

    property Left: Integer read GetLeft write SetLeft;
    property Right: Integer read GetRight;
    property Top: Integer read GetTop write SetTop;
    property Bottom: Integer read GetBottom;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight write SetHeight;
    property BaseWidth: Integer read fBaseWidth write fBaseWidth;
    property BaseHeight: Integer read fBaseHeight write fBaseHeight;

    property Center: TKMPoint read GetCenter;
    property ID: Integer read fID;
    function GetIDsStr: String;
    property Hint: UnicodeString read GetHint write SetHint; //Text that shows up when cursor is over that control, mainly for Buttons
    property HintKind: TKMHintKind read GetHintKind;
    property HintFont: TKMFont read GetHintFont;
    property HintSelected: Boolean read IsHintSelected;
    property HintBackColor: TKMColor4f read GetHintBackColor write SetHintBackColor;
    property HintTextColor: TColor4 read GetHintTextColor;
    property HintBackRect: TKMRect read GetHintBackRect;
    property HintTextOffset: TKMPoint read GetHintTextOffset;

    property MouseWheelStep: Integer read fMouseWheelStep write fMouseWheelStep;

    property FitInParent: Boolean read fFitInParent write fFitInParent;

    // "Self" coordinates - this is the coordinates of control itself.
    // For simple controls they are equal to normal coordinates
    // but for composite controls this is coord. for control itself, without any other controls inside composite
    // (f.e. for TKMNumericEdit this is his internal edit coord without Inc/Dec buttons)
    property SelfAbsLeft: Integer read GetSelfAbsLeft;
    property SelfAbsTop: Integer read GetSelfAbsTop;
    property SelfWidth: Integer read GetSelfWidth;
    property SelfHeight: Integer read GetSelfHeight;

    property Rect: TKMRect read GetControlRect;
    property AbsRect: TKMRect read GetControlAbsRect;
    property Anchors: TKMAnchorsSet read fAnchors write SetAnchors;
    property Enabled: Boolean read fEnabled write SetEnabled;
    property Visible: Boolean read GetVisible write SetVisible;
    property Focusable: Boolean read fFocusable write SetFocusable;
    property IsSetVisible: Boolean read fVisible;
    property IsPainted: Boolean read GetIsPainted;
    property IsFocused: Boolean read GetIsFocused;
    property IsClickable: Boolean read GetIsClickable;  // Control considered 'Clickabale' if it is Visible and Enabled
    property ControlIndex: Integer read fControlIndex;
    procedure Enable;
    procedure Disable;
    procedure Show;
    procedure Hide;
    procedure DoSetVisible; //Differs from Show, that we do not force to show Parents
    procedure Focus;
    procedure Unfocus;
    procedure AnchorsCenter;
    procedure AnchorsStretch;
    procedure ToggleVisibility;
    function MasterParent: TKMPanel;

    procedure SetPosCenter;
    procedure SetPosCenterW;
    procedure SetPosCenterH;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; virtual;
    procedure KeyPress(Key: Char); virtual;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; virtual;
    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;
    procedure MouseMove (X,Y: Integer; Shift: TShiftState); virtual;
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); virtual;

    property OnClick: TNotifyEvent read fOnClick write fOnClick;
    property OnClickShift: TNotifyEventShift read fOnClickShift write fOnClickShift;
    property OnClickRight: TPointEvent read fOnClickRight write fOnClickRight;
    property OnClickHold: TNotifyEvenClickHold read fOnClickHold write fOnClickHold;
    property OnDoubleClick: TNotifyEvent read fOnDoubleClick write fOnDoubleClick;
    property OnMouseWheel: TNotifyEventMW read fOnMouseWheel write fOnMouseWheel;
    property OnFocus: TBooleanObjEvent read fOnFocus write fOnFocus;
    property OnChangeVisibility: TBooleanObjEvent read fOnChangeVisibility write fOnChangeVisibility;
    property OnChangeEnableStatus: TBooleanObjEvent read fOnChangeEnableStatus write fOnChangeEnableStatus;
    property OnKeyDown: TNotifyEventKeyShiftFunc read fOnKeyDown write fOnKeyDown;
    property OnKeyUp: TNotifyEventKeyShiftFunc read fOnKeyUp write fOnKeyUp;

    property OnWidthChange: TObjectIntegerEvent read fOnWidthChange write fOnWidthChange;
    property OnHeightChange: TObjectIntegerEvent read fOnHeightChange write fOnHeightChange;
    property OnSizeSet: TNotifyEvent read fOnSizeSet write fOnSizeSet;
    property OnPositionSet: TNotifyEvent read fOnPositionSet write fOnPositionSet;

    procedure Paint; virtual;
    procedure UpdateState(aTickCount: Cardinal); virtual;

    function ToStr: string;
  end;

  TKMControlClass = class of TKMControl;
  TKMControlClassArray = array of TKMControlClass;


  { Panel which keeps child items in it, it's virtual and invisible }
  TKMPanel = class(TKMControl)
  private
    fMasterControl: TKMMasterControl;
    procedure Init;
    procedure Paint; reintroduce;
  protected
    //Do not propogate SetEnabled and SetVisible because that would show/enable ALL childs childs
    //e.g. scrollbar on a listbox
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;

//    procedure ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
//    procedure ControlMouseUp(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure UpdateVisibility; override;
    procedure UpdateEnableStatus; override;
    function DoPanelHandleMouseWheelByDefault: Boolean; virtual;
    procedure DoPaint(aPaintLayer: Integer); virtual;

    procedure Enlarge(aChild: TKMControl);
  public
    PanelHandleMouseWheelByDefault: Boolean; //Do whole panel handle MW by default? Usually it is
    FocusedControlIndex: Integer; //Index of currently focused control on this Panel
    ChildCount: Word;
    Childs: array of TKMControl;
    constructor Create(aParent: TKMMasterControl; aLeft, aTop, aWidth, aHeight: Integer; aPaintLevel: Integer = 0); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLevel: Integer = 0); overload;
    destructor Destroy; override;
    function AddChild(aChild: TKMControl): Integer; virtual;
    procedure SetCanChangeEnable(aEnable: Boolean; aExceptControls: array of TKMControlClass; aAlsoSetEnable: Boolean = True);

    function FindFocusableControl(aFindNext: Boolean): TKMControl;
    procedure FocusNext;
    procedure ResetFocusedControlIndex;

    property MasterControl: TKMMasterControl read fMasterControl;

    procedure PaintPanel(aPaintLayer: Integer); virtual;

    procedure UpdateState(aTickCount: Cardinal); override;
  end;


  { Beveled area }
  TKMBevel = class(TKMControl)
  const
    DEF_BACK_ALPHA = 0.4;
    DEF_EDGE_ALPHA = 0.75;
  public
    BackAlpha: Single;
    EdgeAlpha: Single;
    Color: TKMColor3f;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLayer: Integer = 0);

    procedure SetDefBackAlpha;
    procedure SetDefEdgeAlpha;
    procedure SetDefColor;

    procedure Paint; override;
  end;


  {Rectangle}
  TKMShape = class(TKMControl)
  public
    FillColor: TColor4;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLayer: Integer = 0);
    procedure Paint; override;
  end;


  {Text Label}
  TKMLabel = class(TKMControl)
  private
    fAutoWrap: Boolean;
    fAutoCut: Boolean;
    fFont: TKMFont;
    fFontColor: TColor4; //Usually white (self-colored)
    fCaption: UnicodeString; //Original text
    fText: UnicodeString; //Reformatted text
    fTextAlign: TKMTextAlign;
    fTextVAlign: TKMTextVAlign;
    fTextSize: TKMPoint;
    fStrikethrough: Boolean;
    fTabWidth: Integer;

    function TextLeft: Integer;
    procedure SetCaption(const aCaption: UnicodeString);
    procedure SetAutoWrap(aValue: Boolean);
    procedure SetAutoCut(aValue: Boolean);
    procedure ReformatText;
    procedure SetFont(const Value: TKMFont);
  protected
    function GetIsPainted: Boolean; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString;
                       aFont: TKMFont; aTextAlign: TKMTextAlign; aPaintLayer: Integer = 0); overload;
    constructor Create(aParent: TKMPanel; aLeft,aTop: Integer; const aCaption: UnicodeString; aFont: TKMFont;
                       aTextAlign: TKMTextAlign; aPaintLayer: Integer = 0); overload;

    function HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): Boolean; override;
    procedure SetColor(aColor: Cardinal);

    property AutoWrap: Boolean read fAutoWrap write SetAutoWrap;  //Whether to automatically wrap text within given text area width
    property AutoCut: Boolean read fAutoCut write SetAutoCut;     //Whether to automatically cut text within given text area size
    property Caption: UnicodeString read fCaption write SetCaption;
    property FontColor: TColor4 read fFontColor write fFontColor;
    property Strikethrough: Boolean read fStrikethrough write fStrikethrough;
    property TabWidth: Integer read fTabWidth write fTabWidth;
    property TextSize: TKMPoint read fTextSize;
    property TextVAlign: TKMTextVAlign read fTextVAlign write fTextVAlign;
    property Font: TKMFont read fFont write SetFont;
    procedure Paint; override;
  end;


  //Label that is scrolled within an area. Used in Credits
  TKMLabelScroll = class(TKMLabel)
  public
    SmoothScrollToTop: cardinal; //Delta between this and TimeGetTime affects vertical position
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign);
    procedure Paint; override;
  end;


  {Image}
  TKMImage = class(TKMControl)
  private
    fRX: TRXType;
    fTexID: Word;
    fFlagColor: TColor4;
  protected
    function GetIsPainted: Boolean; override;
  public
    ImageAnchors: TKMAnchorsSet;
    Highlight: Boolean;
    HighlightOnMouseOver: Boolean;
    HighlightCoef: Single;
    Lightness: Single;
    ClipToBounds: Boolean;
    Tiled: Boolean;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType = rxGui;
                       aPaintLayer: Integer = 0; aImageAnchors: TKMAnchorsSet = [anLeft, anTop]);
    property RX: TRXType read fRX write fRX;
    property TexID: Word read fTexID write fTexID;
    property FlagColor: TColor4 read fFlagColor write fFlagColor;
    function Click: Boolean;
    procedure ImageStretch;
    procedure ImageCenter;
    procedure Paint; override;
  end;


  {Image stack - for army formation view}
  TKMImageStack = class(TKMControl)
  private
    fRX: TRXType;
    fTexID1, fTexID2: Word; //Normal and commander
    fCount: Integer;
    fColumns: Integer;
    fDrawWidth: Integer;
    fDrawHeight: Integer;
    fHighlightID: Integer;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID1, aTexID2: Word; aRX: TRXType = rxGui);
    procedure SetCount(aCount, aColumns, aHighlightID: Word);
    procedure Paint; override;
  end;


  { Color swatch - to select a color from given samples/palette }
  TKMColorSwatch = class(TKMControl)
  private
    fBackAlpha: single; //Alpha of background (usually 0.5, dropbox 1)
    fCellSize: Byte; //Size of the square in pixels
    fColumnCount: Byte;
    fRowCount: Byte;
    fColorIndex: Integer;
    Colors: array of TColor4;
    fOnChange: TNotifyEvent;
    fInclRandom: Boolean;
  public
    constructor Create(aParent: TKMPanel; aLeft,aTop,aColumnCount,aRowCount,aSize: Integer);
    procedure SetColors(const aColors: array of TColor4; aInclRandom: Boolean = False);
    procedure SelectByColor(aColor: TColor4);
    property BackAlpha: single read fBackAlpha write fBackAlpha;
    property ColorIndex: Integer read fColorIndex write fColorIndex;
    function GetColor: TColor4;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    property OnChange: TNotifyEvent write fOnChange;
    procedure Paint; override;
  end;


  {3DButton}
  TKMButton = class(TKMControl)
  private
    fCaption: UnicodeString;
    fTextAlign: TKMTextAlign;
    fStyle: TKMButtonStyle;
    fRX: TRXType;
    fAutoHeight: Boolean; //Set button height automatically depending text size (height)
    procedure InitCommon(aStyle: TKMButtonStyle);
    procedure SetCaption(const aCaption: UnicodeString);
    procedure SetAutoHeight(aValue: Boolean);
    procedure UpdateHeight;
  public
    FlagColor: TColor4; //When using an image
    Font: TKMFont;
    MakesSound: Boolean;
    TexID: Word;
    CapOffsetX: Shortint;
    CapOffsetY: Shortint;
    ShowImageEnabled: Boolean; // show picture as enabled or not (normal or darkened)
    TextVAlign: TKMTextVAlign;
    AutoTextPadding: Byte;      //text padding for autoHeight
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType;
                       aStyle: TKMButtonStyle; aPaintLayer: Integer = 0); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString;
                       aStyle: TKMButtonStyle; aPaintLayer: Integer = 0); overload;
    function Click: Boolean; //Try to click a button and return TRUE if succeded

    property Caption: UnicodeString read fCaption write SetCaption;
    property AutoHeight: Boolean read fAutoHeight write SetAutoHeight;

    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure Paint; override;
  end;


  {Common Flat Button}
  TKMButtonFlatCommon = class(TKMControl)
  private
  public
    RX: TRXType;
    TexID: Word;
    TexOffsetX: Shortint;
    TexOffsetY: Shortint;
    CapOffsetX: Shortint;
    CapOffsetY: Shortint;
    Caption: UnicodeString;
    CapColor: TColor4;
    FlagColor: TColor4;
    Font: TKMFont;
    HideHighlight: Boolean;
    Clickable: Boolean; //Disables clicking without dimming

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight, aTexID: Integer; aRX: TRXType = rxGui);

    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure Paint; override;

  end;


  {FlatButton}
  TKMButtonFlat = class(TKMButtonFlatCommon)
  public
    Down: Boolean;
    procedure Paint; override;
  end;


  {FlatButton with Shape on it}
  TKMFlatButtonShape = class(TKMControl)
  private
    fCaption: UnicodeString;
    fFont: TKMFont;
    fFontHeight: Byte;
  public
    Down: Boolean;
    FontColor: TColor4;
    ShapeColor: TColor4;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aShapeColor: TColor4);
    procedure Paint; override;
  end;


  TKMAllowedChars = (
    acDigits, //Only 0..9 digits, for numeric input
    acHex,    //Only 0..9 A..F a..f, for input hex values (colors)
    acANSI7,  //#33..#123,#125,#126 - only basic latin chars and symbols for user nikname, except |
    acFileName, //Exclude symbols that can't be used in filenames
    acText,  //Anything is allowed except for eol symbol
    acAll    //Anything is allowed
  );


  // Check if specified aChar is allowed for specified aAllowedChars type
  function IsCharAllowed(aChar: WideChar; aAllowedChars: TKMAllowedChars): Boolean;

const
  DEFAULT_HIGHLIGHT_COEF = 0.4;


type

  //Form that can be dragged around (and resized?)
  TKMForm = class(TKMPanel)
  private
    fHeaderHeight: Integer;
    fButtonClose: TKMButtonFlat;
    fLabelCaption: TKMLabel;

    fDragging: Boolean;
    fOffsetX: Integer;
    fOffsetY: Integer;
    function HitHeader(X, Y: Integer): Boolean;
    procedure FormCloseClick(Sender: TObject);
    function GetCaption: UnicodeString;
    procedure SetCaption(const aValue: UnicodeString);
  public
    OnMove: TNotifyEvent;
    OnClose: TNotifyEvent;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    property Caption: UnicodeString read GetCaption write SetCaption;
    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove (X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure PaintPanel(aPaintLayer: Integer); override;
  end;


  //Selectable Edit - Basic Edit class with selection available
  TKMSelectableEdit = class(TKMControl)
  private
    fFont: TKMFont;
    fLeftIndex: Integer; //The position of the character shown left-most when text does not fit

    fCursorPos: Integer;
    fSelectable: Boolean;
    fSelectionStart: Integer;
    fSelectionEnd: Integer;
    fSelectionInitialPos: Integer;

    procedure SetCursorPos(aPos: Integer);
    function GetCursorPosAt(X: Integer): Integer;
    procedure ResetSelection;
    function HasSelection: Boolean;
    function GetSelectedText: UnicodeString;
    procedure SetSelectionStart(aValue: Integer);
    procedure SetSelectionEnd(aValue: Integer);
    procedure DeleteSelectedText;
    procedure SetSelections(aValue1, aValue2: Integer);
    procedure UpdateSelection(aOldCursorPos: Integer; aIsSelecting: Boolean);
  protected
    fText: UnicodeString;
    procedure SelEditCtrlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    procedure FocusChanged(aFocused: Boolean); override;
    function GetMaxLength: Word; virtual; abstract;
    function IsCharValid(aChar: WideChar): Boolean; virtual; abstract;
    procedure ValidateText(aTriggerOnChange: Boolean = True); virtual;
    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; virtual; abstract;
    procedure PaintSelection;
    function DrawEolSymbol: Boolean; virtual;
    function DoShowMarkup: Boolean; virtual;
//    function GetControlMouseDownProc: TKMMouseUpDownEvent; virtual;

    procedure Changed;
  public
    ReadOnly: Boolean;
    BlockInput: Boolean; // Blocks all input into the field, but allow focus, selection and copy selected text

    OnChange: TNotifyEvent;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);

    property CursorPos: Integer read fCursorPos write SetCursorPos;
    property Selectable: Boolean read fSelectable write fSelectable;
    property SelectionStart: Integer read fSelectionStart write SetSelectionStart;
    property SelectionEnd: Integer read fSelectionEnd write SetSelectionEnd;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure KeyPress(Key: Char); override;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; override;
  end;

  {EditField}
  TKMEdit = class(TKMSelectableEdit)
  private
    fAllowedChars: TKMAllowedChars;
    procedure SetText(const aText: UnicodeString);
  protected
    function GetMaxLength: Word; override;
    function IsCharValid(aChar: WideChar): Boolean; override;
    procedure ValidateText(aTriggerOnChange: Boolean = True); override;
    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; override;
    function GetRText: UnicodeString;
    function DrawEolSymbol: Boolean; override;
    function DoShowMarkup: Boolean; override;
  public
    Masked: Boolean; //Mask entered text as *s
    MaxLen: Word;
    ShowColors: Boolean;
    DrawOutline: Boolean;
    OutlineColor: Cardinal;
    OnIsKeyEventHandled: TNotifyEventKeyFunc; //Invoked to check is key overrides default handle policy or not
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);

    property AllowedChars: TKMAllowedChars read fAllowedChars write fAllowedChars;
    property Text: UnicodeString read fText write SetText;
    procedure UpdateText(const aText: UnicodeString; aTriggerOnChange: Boolean = True);
    procedure SetTextSilently(const aText: UnicodeString);

    function HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): Boolean; override;
    procedure Paint; override;
  end;


  TKMFilenameEdit = class(TKMEdit)
  private
    function GetIsValid: Boolean;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);

    property IsValid: Boolean read GetIsValid;
  end;


  TKMCheckBoxState = (cbsUnchecked, cbsSemiChecked, cbsChecked);

  { Checkbox }
  TKMCheckBox = class(TKMControl)
  private
    fCaption: UnicodeString;
    fState: TKMCheckBoxState;
    fHasSemiState: Boolean;
    fFont: TKMFont;

    function GetCheckedBool: Boolean;
  public
    DrawOutline: Boolean;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString;
                       aFont: TKMFont; aHasSemiState: Boolean = False); overload;
    property Caption: UnicodeString read fCaption write fCaption;
    procedure SetChecked(aChecked: Boolean);
    property Checked: Boolean read GetCheckedBool write SetChecked;
    property CheckState: TKMCheckBoxState read fState write fState;
    function IsSemiChecked: Boolean;
    procedure Check;
    procedure Uncheck;
    procedure SemiCheck;
    procedure SwitchCheck(aForward: Boolean = True);
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure Paint; override;
  end;


  TKMRadioGroupItem = record
    Text: UnicodeString;
    Hint: UnicodeString;
    Enabled: Boolean;
    Visible: Boolean;
  end;


  { TKMRadioGroup }
  TKMRadioGroup = class(TKMControl)
  private
    fItemIndex: Integer;
    fCount: Integer;
    fItems: array of TKMRadioGroupItem;
    fFont: TKMFont;
    fMouseOverItem: SmallInt;
    fOnChange: TNotifyEvent;
    procedure UpdateMouseOverPositions(X,Y: Integer);
    function GetItem(aIndex: Integer): TKMRadioGroupItem;
    function GetItemIndexByRow(aRowIndex: Integer): Integer;
    function GetVisibleCount: Integer;
    function GetLineHeight: Single;
    function GetIsSelected: Boolean;
  protected
    function GetHint: UnicodeString; override;
  public
    AllowUncheck: Boolean; //Do we allow to uncheck selected element ? Usually not, but its possible
    DrawChkboxOutline: Boolean;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont);

    procedure Add(const aText: String; aEnabled: Boolean = True); overload;
    procedure Add(const aText: String; aEnabled, aVisible: Boolean); overload;
    procedure Add(const aText, aHint: String; aEnabled: Boolean = True; aVisible: Boolean = True); overload;
    procedure Clear;
    property Count: Integer read fCount;
    property IsSelected: Boolean read GetIsSelected;
    property VisibleCount: Integer read GetVisibleCount;
    property ItemIndex: Integer read fItemIndex write fItemIndex;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    property Item[aIndex: Integer]: TKMRadioGroupItem read GetItem;
    procedure SetItemEnabled(aIndex: Integer; aEnabled: Boolean; aUncheckDisabled: Boolean = True);
    procedure SetItemVisible(aIndex: Integer; aEnabled: Boolean);
    procedure CheckFirstCheckable;
    property LineHeight: Single read GetLineHeight;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;

  {Abstract Progress bar}
  TKMProgressBarAbstract = class(TKMControl)
  private
    fFont: TKMFont;
    fTextAlign: TKMTextAlign;
  protected
    procedure PaintBar; virtual; abstract;
  public
    //CaptionLeft and CaptionRight are shown to the left and right from main Caption. Use them only with taCenter
    Caption, CaptionLeft, CaptionRight: UnicodeString;
    FontColor: TColor4;
    TextYOffset: Integer;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fntMini;
                       aPaintLayer: Integer = 0);
    procedure SetCaptions(const aCaptionLeft, aCaption, aCaptionRight: UnicodeString);
    procedure Paint; override;
  end;


  {Percent bar}
  TKMPercentBar = class(TKMProgressBarAbstract)
  private
    fPosition: Single;
    fSeam: Single;
    fMainColor: Cardinal;
    fAddColor: Cardinal;
    procedure SetPosition(aValue: Single);
    procedure SetSeam(aValue: Single);
  protected
    procedure PaintBar; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fntMini;
                       aPaintLayer: Integer = 0);
    property Seam: Single read fSeam write SetSeam;
    property Position: Single read fPosition write SetPosition;
    property MainColor: Cardinal read fMainColor write fMainColor;
    property AddColor: Cardinal read fAddColor write fAddColor;
  end;


  TKMReplayBar = class(TKMPercentBar)
  private
    fIsDirty: Boolean; //True is Marks are not not sorted yet
    fPosition: Integer;
    fPeacetime: Integer;
    fMaxValue: Integer;
    fHighlightMark: Integer;
    fMarks: TList<Integer>;
    fMarksPattern: Word;
    fOnMarkClick: TIntegerEvent;
    fHintResText: Word;
    procedure TrySortMarks;
    procedure SetPosition(aValue: Integer);
    procedure SetPeacetime(aValue: Integer);
    procedure SetMaxValue(aValue: Integer);
  protected
    procedure ControlMouseMove(Sender: TObject; X, Y: Integer; Shift: TShiftState);
    procedure PaintBar; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fntMini); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight, aPosition, aPeacetime, aMaxValue: Integer; aFont: TKMFont = fntMini); overload;
    destructor Destroy; override;

    property Position: Integer read fPosition;
    property Peacetime: Integer read fPeacetime;
    property MaxValue: Integer read fMaxValue write SetMaxValue;

    procedure SetParameters(aPosition, aPeacetime, aMaxValue: Integer);
    property MarksPattern: Word read fMarksPattern write fMarksPattern;
    property HintResText: Word read fHintResText write fHintResText;
//    property Marks: TList<Integer> read GetMarks;

    procedure AddMark(aMark: Integer);
    procedure Clear;

    property OnMarkClick: TIntegerEvent read fOnMarkClick write fOnMarkClick;

    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp  (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
  end;


  {Row with resource name and icons}
  TKMWaresRow = class(TKMButtonFlatCommon)
  public
    WareCount: Word;
    WareCntAsNumber: Boolean;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aClickable: Boolean); overload;
    procedure Paint; override;
  end;


  TKMNumericEdit = class(TKMSelectableEdit)
  private
    fButtonInc: TKMButton;
    fButtonDec: TKMButton;
    fValue: Integer;
    procedure ButtonClick(Sender: TObject; Shift: TShiftState);

    procedure SetValueNCheckRange(aValue: Int64);
    procedure SetValue(aValue: Integer);
    procedure CheckValueOnUnfocus;
    procedure ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
  protected
    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    procedure SetHint(const aValue: UnicodeString); override;
    function GetSelfAbsLeft: Integer; override;
    function GetSelfWidth: Integer; override;
    function GetMaxLength: Word; override;
    function IsCharValid(Key: WideChar): Boolean; override;
    procedure ValidateText(aTriggerOnChange: Boolean = True); override;
    procedure FocusChanged(aFocused: Boolean); override;
    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; override;
    procedure NumEdCtrlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    function DoHandleMouseWheelByDefault: Boolean; override;

  public
    ValueMin: Integer;
    ValueMax: Integer;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aValueMin, aValueMax: Integer; aFont: TKMFont = fntGrey; aSelectable: Boolean = True);
    property Value: Integer read fValue write SetValue;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    procedure Paint; override;
  end;

  {Ware order bar}
  TKMWareOrderRow = class(TKMControl)
  private
    fWaresRow: TKMWaresRow;
    fOrderAdd: TKMButton;
    fOrderLab: TKMLabel;
    fOrderRem: TKMButton;
    fOrderCount: Integer;
    fImmidiateOrder: Boolean; //Order count should be changed immidiately in control. Should be False usually
    procedure ButtonClick(Sender: TObject; Shift: TShiftState);
    procedure ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
    procedure SetOrderRemHint(const aValue: UnicodeString);
    procedure SetOrderAddHint(const aValue: UnicodeString);
    procedure SetOrderCount(aValue: Integer);
  protected
    procedure SetTop(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function DoHandleMouseWheelByDefault: Boolean; override;
  public
    OrderCntMin: Integer;
    OrderCntMax: Integer;
    OnChange: TObjectIntegerEvent;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aOrderCntMax: Integer = MAX_WARES_IN_HOUSE;
                       aOrderCntMin: Integer = 0; aImmidiateOrder: Boolean = False);
    property WareRow: TKMWaresRow read fWaresRow;
    property OrderCount: Integer read fOrderCount write SetOrderCount;
    property OrderRemHint: UnicodeString write SetOrderRemHint;
    property OrderAddHint: UnicodeString write SetOrderAddHint;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    procedure Paint; override;
  end;


  {Production cost bar}
  TKMCostsRow = class(TKMControl)
  private
  public
    RX: TRXType;
    TexID1, TexID2: Word;
    Count: Byte;
    Caption: UnicodeString;
    MaxCount: Byte;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aMaxCount: Byte = 6);
    procedure Paint; override;
  end;


  TKMTrackBar = class(TKMControl)
  private
    fTrackTop: Byte; //Offset trackbar from top (if Caption <> '')
    fTrackHeight: Byte; //Trackbar height
    fMinValue: Word;
    fMaxValue: Word;
    fOnChange: TNotifyEvent;
    fCaption: UnicodeString;
    fPosition: Word;
    fFont: TKMFont;
    fRange: TKMRangeInt;
    fThumbText: UnicodeString;
    fAutoThumbWidth: Boolean;
    fFixedThumbWidth: Boolean;
    procedure SetCaption(const aValue: UnicodeString);
    procedure SetPosition(aValue: Word);
    procedure SetRange(const aRange: TKMRangeInt);
    procedure UpdateThumbWidth;
    procedure SetThumbText(const Value: UnicodeString);
    procedure SetAutoThumbWidth(const aValue: Boolean);
  protected
    function DoHandleMouseWheelByDefault: Boolean; override;
  public
    Step: Byte; //Change Position by this amount each time
    ThumbWidth: Word;
    CaptionWidth: Integer;
    SliderFont: TKMFont;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aMin, aMax: Word);

    property Caption: UnicodeString read fCaption write SetCaption;
    property Position: Word read fPosition write SetPosition;
    property Range: TKMRangeInt read fRange write SetRange;
    property Font: TKMFont read fFont write fFont;
    property MinValue: Word read fMinValue;
    property MaxValue: Word read fMaxValue;
    property ThumbText: UnicodeString read fThumbText write SetThumbText;
    property AutoThumbWidth: Boolean read fAutoThumbWidth write SetAutoThumbWidth;
    property FixedThumbWidth: Boolean read fAutoThumbWidth write fFixedThumbWidth;
    procedure ResetRange;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    procedure Paint; override;
  const
    THUMB_WIDTH_ADD = 24;
  end;


  TKMScrollAxis = (saVertical, saHorizontal);
  TKMScrollStyle = (ssGame, ssCommon);
  TKMScrollAxisSet = set of TKMScrollAxis;

  TKMScrollBar = class(TKMPanel)
  private
    fScrollAxis: TKMScrollAxis;
    fStyle: TKMButtonStyle;
    fMinValue: Integer;
    fMaxValue: Integer;
    fPosition: Integer;
    fThumbPos: Integer; //Position of the thumb
    fThumbSize: Word; //Length of the thumb
    fOffset: Integer;
    fScrollDec: TKMButton;
    fScrollInc: TKMButton;
    fOnChange: TNotifyEvent;
    procedure SetMinValue(Value: Integer);
    procedure SetMaxValue(Value: Integer);
    procedure SetPosition(Value: Integer);
    procedure IncPosition(Sender: TObject);
    procedure DecPosition(Sender: TObject);
    procedure UpdateThumbPos;
    procedure UpdateThumbSize;
  protected
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    function DoHandleMouseWheelByDefault: Boolean; override;
  public
    BackAlpha: Single; //Alpha of background (usually 0.5, dropbox 1)
    EdgeAlpha: Single; //Alpha of background outline (usually 1)
    WheelStep: Word;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aScrollAxis: TKMScrollAxis;
                       aStyle: TKMButtonStyle; aScrollStyle: TKMScrollStyle = ssGame; aPaintLevel: Integer = 0);
    property MinValue: Integer read fMinValue write SetMinValue;
    property MaxValue: Integer read fMaxValue write SetMaxValue;
    property Position: Integer read fPosition write SetPosition;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure PaintPanel(aPaintLayer: Integer); override;
  end;


  TKMScrollPanel = class(TKMPanel)
  private
    fClipRect: TKMRect;
    fChildsPanel: TKMPanel;
    fScrollBarH: TKMScrollBar;
    fScrollBarV: TKMScrollBar;
    fScrollAxisSet: TKMScrollAxisSet;

    fPadding: TKMRect;
    fScrollV_PadTop: Integer;
    fScrollV_PadBottom: Integer;

    procedure UpdateScrolls(Sender: TObject; aValue: Boolean); overload;
    procedure UpdateScrolls(Sender: TObject); overload;
    procedure UpdateScrollV; overload;
    procedure UpdateScrollV(aChildsRect: TKMRect); overload;
    procedure UpdateScrollV(Sender: TObject; aValue: Integer); overload;
    procedure UpdateScrollH; overload;
    procedure UpdateScrollH(aChildsRect: TKMRect); overload;
    procedure UpdateScrollH(Sender: TObject; aValue: Integer); overload;
    procedure ScrollChanged(Sender: TObject);
    function GetChildsRect: TKMRect;

    function AllowScrollV: Boolean;
    function AllowScrollH: Boolean;
    procedure SetScrollVPadTop(const Value: Integer);
    procedure SetScrollVPadBottom(const Value: Integer);
  protected
    procedure SetVisible(aValue: Boolean); override;

    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;

    function GetDrawRect: TKMRect; override;

    function GetAbsDrawLeft: Integer; override;
    function GetAbsDrawTop: Integer; override;
    function GetAbsDrawRight: Integer; override;
    function GetAbsDrawBottom: Integer; override;

    procedure UpdateVisibility; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aScrollAxisSet: TKMScrollAxisSet;
                       aStyle: TKMButtonStyle; aScrollStyle: TKMScrollStyle; aEnlargeParents: Boolean = False);

    property ScrollH: TKMScrollBar read fScrollBarH;
    property ScrollV: TKMScrollBar read fScrollBarV;

    function AddChild(aChild: TKMControl): Integer; override;
    property ClipRect: TKMRect read fClipRect;
    property Padding: TKMRect read fPadding write fPadding;
    property ScrollV_PadTop: Integer read fScrollV_PadTop write SetScrollVPadTop;
    property ScrollV_PadBottom: Integer read fScrollV_PadBottom write SetScrollVPadBottom;

    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;

    procedure PaintPanel(aPaintLayer: Integer); override;
  end;


  TKMSearchableList = class(TKMControl)
  private
    fSearch: UnicodeString; //Contains user input characters we should search for
    fLastKeyTime: Cardinal;
  protected
    fFont: TKMFont; //Should not be changed from inital value, it will mess up the word wrapping
    fOnChange: TNotifyEvent;
    function GetHintKind: TKMHintKind; override;
    function GetHintFont: TKMFont; override;
    function IsHintSelected: Boolean; override;

    function CanSearch: Boolean; virtual; abstract;
    function GetRowCount: Integer; virtual; abstract;
    function GetItemIndex: Integer; virtual; abstract;
    procedure SetItemIndex(aIndex: Integer); virtual; abstract;
    function GetTopIndex: Integer; virtual; abstract;
    procedure SetTopIndex(aIndex: Integer); overload; virtual; abstract;
    function GetVisibleRows: Integer; virtual; abstract;
    function GetItemString(aIndex: Integer): UnicodeString; virtual; abstract;
    function GetMouseOverRow: Integer; virtual; abstract;

    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; virtual;
    function CanChangeSelection: Boolean; virtual;
  public
    procedure SetTopIndex(aIndex: Integer; aStayOnList: Boolean); overload;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property TopIndex: Integer read GetTopIndex write SetTopIndex;
    property RowCount: Integer read GetRowCount;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure KeyPress(Key: Char); override;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; override;
  end;


  TKMListBox = class(TKMSearchableList)
  const
    TXT_PAD_X = 4;
    TXT_PAD_Y = 3;
  private
    fAutoHideScrollBar: Boolean;
    fBackAlpha: Single; //Alpha of background (usually 0.5, dropbox 1)
    fItemHeight: Byte;
    fItemIndex: Integer;
    fItems: TStringList;
    fMouseOverRow: SmallInt;
    fShowHintWhenShort: Boolean;
    fSeparatorPositions: array of Integer;
    fSeparatorHeight: Byte;
    fSeparatorColor: TColor4;
    fSeparatorTexts: TStringList;
    fSeparatorFont: TKMFont;
    fScrollBar: TKMScrollBar;
    fSearchEnabled: Boolean;
    procedure SetBackAlpha(aValue: single);
    procedure SetItemHeight(const Value: byte);
    procedure SetAutoHideScrollBar(Value: boolean);
    function GetItem(aIndex: Integer): UnicodeString;
    function GetSeparatorPos(aIndex: Integer): Integer;
    function GetItemTop(aIndex: Integer): Integer;

    function GetPaintWidth: Integer;
    function GetRenderTextWidth: Integer;

    property PaintWidth: Integer read GetPaintWidth;
    property RenderTextWidth: Integer read GetRenderTextWidth;
  protected
    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function GetSelfWidth: Integer; override;
    function DoHandleMouseWheelByDefault: Boolean; override;

    function GetHint: UnicodeString; override;
    function GetHintBackRect: TKMRect; override;
    function GetHintTextOffset: TKMPoint; override;

    //TKMSearchableList
    function CanSearch: Boolean; override;
    function GetRowCount: Integer; override;
    function GetItemIndex: Integer; override;
    procedure SetItemIndex(aIndex: Integer); override;
    function GetTopIndex: Integer; override;
    procedure SetTopIndex(aIndex: Integer); override;
    function GetItemString(aIndex: Integer): UnicodeString; override;
    function GetMouseOverRow: Integer; override;
  public
    ItemTags: array of Integer;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle;
                       aPaintLayer: Integer = 0);
    destructor Destroy; override;

    property AutoHideScrollBar: boolean read fAutoHideScrollBar write SetAutoHideScrollBar;
    property BackAlpha: Single write SetBackAlpha;

    property SearchEnabled: Boolean read fSearchEnabled write fSearchEnabled;

    procedure Add(const aItem: UnicodeString; aTag: Integer = 0);
    procedure AddSeparator(aPosition: Integer; const aText: String = '');
    procedure ClearSeparators;

    procedure Clear;
    function Count: Integer;
    function SeparatorsCount: Integer;

    function GetVisibleRows: Integer; override;

    property Item[aIndex: Integer]: UnicodeString read GetItem; default;
    property ItemHeight: Byte read fItemHeight write SetItemHeight; //Accessed by DropBox
    property Items: TStringList read fItems;
    procedure UpdateScrollBar;

    property ShowHintWhenShort: Boolean read fShowHintWhenShort write fShowHintWhenShort;

    property SeparatorPos[aIndex: Integer]: Integer read GetSeparatorPos;
    property SeparatorFont: TKMFont read fSeparatorFont write fSeparatorFont;
    property SeparatorColor: TColor4 read fSeparatorColor write fSeparatorColor;
    property SeparatorHeight: Byte read fSeparatorHeight write fSeparatorHeight;

    function Selected: Boolean;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;

    procedure Paint; override;
  end;

  TSortDirection = (sdNone, sdUp, sdDown);

  TKMListHeaderColumn = class
    Caption: UnicodeString;
    Glyph: TKMPic;
    HeaderHint: UnicodeString;
    Offset: Word; //Offsets are easier to handle than widths
  end;

  TKMListHeader = class(TKMControl)
  private
    fFont: TKMFont;
    fCount: Integer;
    fColumns: array of TKMListHeaderColumn;
    fColumnHighlight: Integer;
    fSortIndex: Integer;
    fSortDirection: TSortDirection;
    fTextAlign: TKMTextAlign;
    function GetColumnIndex(X: Integer): Integer;
    function GetColumn(aIndex: Integer): TKMListHeaderColumn;
    procedure ClearColumns;
    function GetColumnWidth(aIndex: Integer): Integer;
    function GetOffset(aIndex: Integer): Word;
    procedure SetOffset(aIndex: Integer; aValue: Word);
    function GetHeaderHint(aIndex: Integer): UnicodeString;
    procedure SetHeaderHint(aIndex: Integer; const aValue: UnicodeString);
  protected
    procedure DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    function GetHint: UnicodeString; override;
  public
    BackAlpha: Single; //Alpha of background
    EdgeAlpha: Single; //Alpha of background outline

    OnColumnClick: TIntegerEvent;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    destructor Destroy; override;

    procedure SetColumns(aFont: TKMFont; aColumns: array of String; aColumnOffsets: array of Word); overload;
    procedure SetColumns(aFont: TKMFont; aColumns, aHints: array of String; aColumnOffsets: array of Word); overload;
    property Offset[aIndes: Integer]: Word read GetOffset write SetOffset;
    property HeaderHint[aIndes: Integer]: UnicodeString read GetHeaderHint write SetHeaderHint;

    property Count: Integer read fCount;
    property Font: TKMFont read fFont write fFont;
    property ColumnCount: Integer read fCount;
    property Columns[aIndex: Integer]: TKMListHeaderColumn read GetColumn;
    property SortIndex: Integer read fSortIndex write fSortIndex;
    property SortDirection: TSortDirection read fSortDirection write fSortDirection;
    property TextAlign: TKMTextAlign read fTextAlign write fTextAlign;
    property ColumnWidth[aIndex: Integer]: Integer read GetColumnWidth;

    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;

  TKMListRow = record
    Cells: array of record
      Caption: UnicodeString;  //Main Text
      SubTxt: UnicodeString; //Gray text below main text
      CellHint: UnicodeString;
      Color: TColor4;
      HighlightColor: TColor4;
      HighlightOnMouseOver: Boolean;
      Enabled: Boolean;
      Pic: TKMPic;
    end;
    Tag: Integer;
  end;

  TKMListColumn = class
    Font: TKMFont;
    HintFont: TKMFont;
    TextAlign: TKMTextAlign;
    TriggerOnChange: Boolean;
  end;

  TKMColumnBox = class(TKMSearchableList)
  const
    COL_PAD_X = 4;
    TXT_PAD_Y = 2;
  private
    fBackAlpha: Single; //Alpha of background
    fEdgeAlpha: Single; //Alpha of outline
    fItemHeight: Byte;
    fItemIndex: Integer;
    fSearchColumn: ShortInt; //which columns text we should search, -1 for disabled
    fRowCount: Integer;
    fColumns: array of TKMListColumn;
    fHeader: TKMListHeader;
    fShowHeader: Boolean;
    fShowLines: Boolean;
    fMouseOverRow: SmallInt;
    fShowHintWhenShort: Boolean;
    fMouseOverColumn: SmallInt;
    fMouseOverCell: TKMPoint;
    fScrollBar: TKMScrollBar;
    fOnCellClick: TPointEventFunc;
    fOnCellClickShift: TPointEventShiftFunc;
    fOnChangeInvoked: Boolean;
    procedure SetBackAlpha(aValue: Single);
    procedure SetEdgeAlpha(aValue: Single);
    function GetSortIndex: Integer;
    procedure SetSortIndex(aIndex: Integer);
    function GetSortDirection: TSortDirection;
    procedure SetSortDirection(aDirection: TSortDirection);
    procedure UpdateScrollBar;
    procedure SetShowHeader(aValue: Boolean);
    function GetOnColumnClick: TIntegerEvent;
    procedure SetOnColumnClick(const Value: TIntegerEvent);
    function GetColumn(aIndex: Integer): TKMListColumn;
    procedure ClearColumns;
    procedure SetSearchColumn(aValue: ShortInt);
    procedure UpdateMouseOverPosition(X,Y: Integer);
    procedure UpdateItemIndex(Shift: TShiftState; var aOnChangeInvoked: Boolean);
    function GetItem(aIndex: Integer): TKMListRow;
    function GetSelectedItem: TKMListRow;
    function GetSelectedItemTag: Integer;
    procedure ScrollBarChangeVisibility;
  protected
    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function GetSelfAbsTop: Integer; override;
    function GetSelfHeight: Integer; override;
    function GetSelfWidth: Integer; override;
    function DoHandleMouseWheelByDefault: Boolean; override;
    procedure DoPaintLine(aIndex: Integer; X,Y: Integer; PaintWidth: Integer; aAllowHighlight: Boolean = True); overload;
    procedure DoPaintLine(aIndex: Integer; X, Y: Integer; PaintWidth: Integer; aColumnsToShow: array of Boolean; aAllowHighlight: Boolean = True); overload;
    function GetHint: UnicodeString; override;
    function GetHintTextColor: TColor4; override;
    function GetHintBackRect: TKMRect; override;
    function GetHintTextOffset: TKMPoint; override;

    // TKMSearchableList methods implementation
    function CanSearch: Boolean; override;
    function GetRowCount: Integer; override;
    function GetItemIndex: Integer; override;
    procedure SetItemIndex(aIndex: Integer); override;
    function GetTopIndex: Integer; override;
    procedure SetTopIndex(aIndex: Integer); override;
    function GetItemString(aIndex: Integer): UnicodeString; override;
    function GetMouseOverRow: Integer; override;

    function CanChangeSelection: Boolean; override;

    function CanFocusNext: Boolean; override;
  public
    HideSelection: Boolean;
    HighlightError: Boolean;
    HighlightOnMouseOver: Boolean;
    Rows: array of TKMListRow; //Exposed to public since we need to edit sub-fields
    PassAllKeys: Boolean;
    ColumnIdForScroll: Integer; //When scroll is visible, we can move columns to the left. Using specified ColumnId. If ColumnId = -1, then no column width is changed

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle);
    destructor Destroy; override;

    property Item[aIndex: Integer]: TKMListRow read GetItem; default;
    property SelectedItem: TKMListRow read GetSelectedItem;
    property SelectedItemTag: Integer read GetSelectedItemTag;
    procedure SetColumns(aHeaderFont: TKMFont; aCaptions: array of String; aOffsets: array of Word); overload;
    procedure SetColumns(aHeaderFont: TKMFont; aCaptions: array of string; aOffsets: array of Word; aCaptionsAsHints: Boolean); overload;
    procedure SetColumns(aHeaderFont: TKMFont; aCaptions, aHints: array of String; aOffsets: array of Word); overload;
    procedure AddItem(aItem: TKMListRow);
    procedure Clear;
    function GetVisibleRows: Integer; override;
    function GetVisibleRowsExact: Single;
    function IsSelected: Boolean;
    property ShowHeader: Boolean read fShowHeader write SetShowHeader;
    property ShowHintWhenShort: Boolean read fShowHintWhenShort write fShowHintWhenShort;
    property ShowLines: Boolean read fShowLines write fShowLines;
    property SearchColumn: ShortInt read fSearchColumn write SetSearchColumn;

    property Columns[aIndex: Integer]: TKMListColumn read GetColumn;
    property BackAlpha: Single read fBackAlpha write SetBackAlpha;
    property EdgeAlpha: Single read fEdgeAlpha write SetEdgeAlpha;
    property RowCount: Integer read fRowCount;
    property ItemHeight: Byte read fItemHeight write fItemHeight;
    property Header: TKMListHeader read fHeader;

    //Sort properties are just hints to render Up/Down arrows. Actual sorting is done by client
    property OnColumnClick: TIntegerEvent read GetOnColumnClick write SetOnColumnClick;
    property OnCellClick: TPointEventFunc read fOnCellClick write fOnCellClick;
    property OnCellClickShift: TPointEventShiftFunc read fOnCellClickShift write fOnCellClickShift;
    property SortIndex: Integer read GetSortIndex write SetSortIndex;
    property SortDirection: TSortDirection read GetSortDirection write SetSortDirection;

    procedure JumpToSelected;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure KeyPress(Key: Char); override;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; override;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    procedure DoClick(X, Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;

    procedure Paint; override;
  end;


  TKMDropCommon = class(TKMControl)
  private
    fDropCount: Byte;
    fDropUp: Boolean;
    fFont: TKMFont;
    fButton: TKMButton;
    fShape: TKMShape;
    fAutoClose: Boolean;

    fOnChange: TNotifyEvent;
    fOnShowList: TNotifyEvent;

    procedure UpdateDropPosition; virtual; abstract;
    procedure ButtonClick(Sender: TObject);
    procedure ListShow(Sender: TObject); virtual;
    procedure ListClick(Sender: TObject); virtual;
    procedure ListChange(Sender: TObject); virtual;
    procedure ListHide(Sender: TObject); virtual;
    function ListVisible: Boolean; virtual; abstract;
    function GetItemIndex: SmallInt; virtual; abstract;
    procedure SetItemIndex(aIndex: SmallInt); virtual; abstract;
  protected
    procedure DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function ListKeyDown(Sender: TObject; Key: Word; Shift: TShiftState): Boolean;
    procedure UpdateVisibility; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle;
                       aAutoClose: Boolean = True; aPaintLayer: Integer = 0);

    procedure Clear; virtual; abstract;
    function Count: Integer; virtual; abstract;
    procedure OpenList;
    procedure CloseList;
    procedure SetOpenList(aOpen: Boolean);
    procedure SwitchOpen;

    property DropCount: Byte read fDropCount write fDropCount;
    property DropUp: Boolean read fDropUp write fDropUp;
    property ItemIndex: SmallInt read GetItemIndex write SetItemIndex;
    function IsOpen: Boolean; virtual;

    property OnShowList: TNotifyEvent read fOnShowList write fOnShowList;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure Paint; override;
  end;


  //DropBox with a ListBox
  TKMDropList = class(TKMDropCommon)
  private
    fCaption: UnicodeString; //Current caption (Default or from list)
    fDefaultCaption: UnicodeString;
    fDropWidth: Integer;
    fList: TKMListBox;
    fListTopIndex: Integer;
    procedure UpdateDropPosition; override;
    procedure ListShow(Sender: TObject); override;
    procedure ListClick(Sender: TObject); override;
    procedure ListChange(Sender: TObject); override;
    procedure ListHide(Sender: TObject); override;
    function ListVisible: Boolean; override;
    function GetItem(aIndex: Integer): UnicodeString;
    function GetItemIndex: smallint; override;
    procedure SetItemIndex(aIndex: smallint); override;
    procedure SetDropWidth(aDropWidth: Integer);
    function GetShowHintWhenShort: Boolean;
    procedure SetShowHintWhenShort(const aValue: Boolean);
  protected
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; const aDefaultCaption: UnicodeString;
                       aStyle: TKMButtonStyle; aAutoClose: Boolean = True; aBackAlpha: Single = 0.85; aPaintLayer: Integer = 0);
    procedure Clear; override;
    function Count: Integer; override;
    procedure Add(const aItem: UnicodeString; aTag: Integer = 0);
    procedure SelectByName(const aText: UnicodeString);
    procedure SelectByTag(aTag: Integer);
    function HasTag(aTag: Integer): Boolean;
    function GetTag(aIndex: Integer): Integer;
    function GetSelectedTag: Integer;
    function IsSelected: Boolean;
    property ShowHintWhenShort: Boolean read GetShowHintWhenShort write SetShowHintWhenShort;
    property DefaultCaption: UnicodeString read fDefaultCaption write fDefaultCaption;
    property Item[aIndex: Integer]: UnicodeString read GetItem;
    property List: TKMListBox read fList;
    function IsOpen: Boolean; override;
    property DropWidth: Integer read fDropWidth write SetDropWidth;

    procedure Paint; override;
  end;


  //DropBox with a ColumnBox
  TKMDropColumns = class(TKMDropCommon)
  private
    fDefaultCaption: UnicodeString;
    fDropWidth: Integer;
    fList: TKMColumnBox;
    fListTopIndex: Integer;
    fColumnsToShowWhenListHidden: array of Boolean; //which columns to show, when list is hidden
    procedure UpdateDropPosition; override;
    procedure ListShow(Sender: TObject); override;
    procedure ListClick(Sender: TObject); override;
    procedure ListChange(Sender: TObject); override;
    procedure ListHide(Sender: TObject); override;
    function ListVisible: Boolean; override;
    function GetItem(aIndex: Integer): TKMListRow;
    function GetItemIndex: Smallint; override;
    procedure SetItemIndex(aIndex: Smallint); override;
    procedure SetDropWidth(aDropWidth: Integer);
    function GetShowHintWhenShort: Boolean;
    procedure SetShowHintWhenShort(const aValue: Boolean);
  protected
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
  public
    FadeImageWhenDisabled: Boolean;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; const aDefaultCaption: UnicodeString; aStyle: TKMButtonStyle; aShowHeader: Boolean = True);
    procedure Add(aItem: TKMListRow);
    procedure Clear; override;
    function Count: Integer; override;
    property List: TKMColumnBox read fList;
    property Item[aIndex: Integer]: TKMListRow read GetItem; default;
    procedure SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word); overload;
    procedure SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word; aColumnsToShowWhenListHidden: array of Boolean); overload;
    property DefaultCaption: UnicodeString read fDefaultCaption write fDefaultCaption;
    property DropWidth: Integer read fDropWidth write SetDropWidth;
    property ShowHintWhenShort: Boolean read GetShowHintWhenShort write SetShowHintWhenShort;

    procedure Paint; override;
  end;


  //DropBox with a ColorSwatch
  TKMDropColors = class(TKMControl)
  private
    fColorIndex: Integer;
    fRandomCaption: UnicodeString;
    fButton: TKMButton;
    fSwatch: TKMColorSwatch;
    fShape: TKMShape;
    fOnChange: TNotifyEvent;
    procedure ListShow(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure ListHide(Sender: TObject);
    procedure SetColorIndex(aIndex: Integer);
    procedure UpdateDropPosition;
  protected
    procedure SetEnabled(aValue: Boolean); override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight,aCount: Integer);
    property ColorIndex: Integer read fColorIndex write SetColorIndex;
    procedure SetColors(const aColors: array of TColor4; const aRandomCaption: UnicodeString = '');
    property OnChange: TNotifyEvent write fOnChange;
    procedure Paint; override;
  end;


  TKMMemo = class(TKMControl)
  private
    fFont: TKMFont; //Should not be changed from inital value, it will mess up the word wrapping
    fItemHeight: Byte;
    fItems: TStringList;
    fAutoWrap: Boolean;
    fIndentAfterNL: Boolean;
    fText: UnicodeString;
    fScrollDown: Boolean;
    fScrollBar: TKMScrollBar;
    fOnChange: TNotifyEvent;
    fCursorPos: Integer;
    fSelectable: Boolean;
    fSelectionStart: Integer;
    fSelectionEnd: Integer;
    fSelectionInitialPos: Integer;

    procedure SetAutoWrap(const Value: Boolean);
    function GetText: UnicodeString;
    procedure SetText(const aText: UnicodeString);
    function GetTopIndex: smallint;
    procedure SetTopIndex(aIndex: SmallInt);
    procedure ReformatText;
    procedure UpdateScrollBar;

    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;

    procedure SetCursorPos(aPos: Integer);
    function LinearToPointPos(aPos: Integer): TKMPoint;
    function PointToLinearPos(aColumn, aRow: Integer): Integer;
    function GetCharPosAt(X,Y: Integer): TKMPoint;
    function GetCursorPosAt(X,Y: Integer): Integer;
    procedure ResetSelection;
    function HasSelection: Boolean;
    function GetPlainText(aUsePipeAsEOL: Boolean; aStart: Integer = -1; aEnd: Integer = -1): UnicodeString;
    function GetSelectedText: UnicodeString;
    function GetMaxCursorPos: Integer;
    function GetMaxPosInRow(aRow: Integer): Integer;
    function GetMinPosInRow(aRow: Integer): Integer;
    function GetMaxCursorPosInRow: Integer;
    function GetMinCursorPosInRow: Integer;
    procedure SetSelectionStart(aValue: Integer);
    procedure SetSelectionEnd(aValue: Integer);
    procedure SetSelections(aValue1, aValue2: Integer);
    procedure UpdateSelection(aOldCursorPos: Integer; aIsSelecting: Boolean);
  protected
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure SetVisible(aValue: Boolean); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetTop(aValue: Integer); override;
    procedure FocusChanged(aFocused: Boolean); override;
    procedure ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    function DoHandleMouseWheelByDefault: Boolean; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle; aSelectable: Boolean = True);
    destructor Destroy; override;

    procedure Add(const aItem: UnicodeString);
    procedure Clear;
    procedure ScrollToBottom;
    property AutoWrap: Boolean read fAutoWrap write SetAutoWrap; //Whether to automatically wrap text within given text area width
    property IndentAfterNL: Boolean read fIndentAfterNL write fIndentAfterNL;
    property Text: UnicodeString read GetText write SetText;
    property ItemHeight: Byte read fItemHeight write fItemHeight;
    property TopIndex: Smallint read GetTopIndex write SetTopIndex;
    property ScrollDown: Boolean read fScrollDown write fScrollDown;
    property CursorPos: Integer read fCursorPos write SetCursorPos;
    property Selectable: Boolean read fSelectable write fSelectable;
    property SelectionStart: Integer read fSelectionStart write SetSelectionStart;
    property SelectionEnd: Integer read fSelectionEnd write SetSelectionEnd;

    function GetVisibleRows: Integer;
    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; override;
    procedure MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean); override;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    property OnChange: TNotifyEvent read fOnChange write fOnChange;

    procedure Paint; override;
  end;


  TKMPopUpMenu = class(TKMPanel)
  private
    fShapeBG: TKMShape;
    fList: TKMColumnBox;
    procedure MenuHide(Sender: TObject);
    procedure MenuClick(Sender: TObject);
    procedure SetItemIndex(aValue: Integer);
    function GetItemIndex: Integer;
    function GetItemTag(aIndex: Integer): Integer;
  public
    constructor Create(aParent: TKMPanel; aWidth: Integer);
    procedure AddItem(const aCaption: UnicodeString; aTag: Integer = 0);
    procedure UpdateItem(aIndex: Integer; const aCaption: UnicodeString);
    procedure Clear;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property ItemTags[aIndex: Integer]: Integer read GetItemTag;
    procedure ShowAt(X,Y: Integer);
    procedure HideMenu;
  end;


  TKMPopUpBGImageType = (pubgitGray, pubgitYellow, pubgitScroll);

  TKMPopUpPanel = class(TKMPanel)
  const
    DEF_FONT: TKMFont = fntOutline;
  private
    fDragging: Boolean;
    fDragStartPos: TKMPoint;
    fBGImageType: TKMPopUpBGImageType;
    fOnClose: TEvent;
    procedure UpdateSizes;
    procedure Close(Sender: TObject);

    function GetLeftRightMargin: Integer;
    function GetTopMargin: Integer;
    function GetBottomMargin: Integer;
    function GetCrossTop: Integer;
    function GetCrossRight: Integer;

    function GetActualWidth: Integer;
    procedure SetActualWidth(aValue: Integer);
    function GetActualHeight: Integer;
    procedure SetActualHeight(aValue: Integer);
  protected
    BevelBG: TKMBevel;
    BevelShade: TKMBevel;
    procedure SetWidth(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
  public
    ItemsPanel: TKMPanel;
    DragEnabled: Boolean;
    ImageBG, ImageClose: TKMImage;
    Caption: UnicodeString;
    Font: TKMFont;
    FontColor: TColor4;
    CapOffsetY: Integer;
    constructor Create(aParent: TKMPanel; aWidth, aHeight: Integer; const aCaption: UnicodeString = '';
                       aImageType: TKMPopUpBGImageType = pubgitYellow; aWithCrossImg: Boolean = False;
                       aShowBevel: Boolean = True; aShowShadeBevel: Boolean = True);

    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove (X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure ControlMouseMove(Sender: TObject; X,Y: Integer; Shift: TShiftState);

    procedure ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    procedure ControlMouseUp(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);

    property OnClose: TEvent read fOnClose write fOnClose;

    property ActualHeight: Integer read GetActualHeight write SetActualHeight;
    property ActualWidth: Integer read GetActualWidth write SetActualWidth;

    procedure PaintPanel(aPaintLayer: Integer); override;
  end;


  TDragAxis = (daHoriz, daVertic, daAll);

  //Element that player can drag within allowed bounds
  TKMDragger = class(TKMControl)
  private
    fMinusX, fMinusY, fPlusX, fPlusY: Integer; //Restrictions
    fPositionX: Integer;
    fPositionY: Integer;
    fStartDragX: Integer;
    fStartDragY: Integer;
  public
    OnMove: TNotifyEventXY;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);

    procedure SetBounds(aMinusX, aMinusY, aPlusX, aPlusY: Integer);

    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure Paint; override;
  end;

  TKMGraphLine = record
                Title: UnicodeString;
                TitleDetailed: TKMStringArray;
                TitleDetailedColor: TKMCardinalArray;
                Tag: Integer;
                Color: TColor4;
                Visible: Boolean;
                Values: TKMCardinalArray;
                ValuesAlt: TKMCardinalArray;
              end;

  TKMChart = class(TKMControl)
  private
    fCaption: UnicodeString;
    fFont: TKMFont;
    fCount: Integer;
    fItemHeight: Byte;
    fLegendWidth: Word;
    fLegendCaption: String;
    fLineOver: Integer;
    fLines: array of TKMGraphLine;
    fMaxLength: Cardinal; //Maximum samples (by horizontal axis)
    fMinTime: Cardinal; //Minimum time (in sec), used only for Rendering time ticks
    fMaxTime: Cardinal; //Maximum time (in sec), used only for Rendering time ticks
    fMaxValue: Cardinal; //Maximum value (by vertical axis)
    fPeaceTime: Cardinal;

    //Legend separators
    fSeparatorPositions: TXStringList;
    fSeparatorHeight: Byte;
    fSeparatorColor: TColor4;

    fOnLegendClick: TObjectIntBoolEvent;
    procedure UpdateMaxValue;
    function GetLine(aIndex:Integer): TKMGraphLine;
    function GetLineNumber(aY: Integer): Integer;
//    function GetSeparatorsHeight(aIndex: Integer): Integer;
    function GetSeparatorPos(aIndex: Integer): Integer;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    destructor Destroy; override;

    procedure AddLine(const aTitle: UnicodeString; aColor: TColor4; const aValues: TKMCardinalArray; aTag: Integer = -1); overload;
    procedure AddLine(const aTitle: UnicodeString; aColor: TColor4; const aTitleDetailed: TKMStringArray;
                      const aTitleDetailedColor: TKMCardinalArray; const aValues: TKMCardinalArray; aTag: Integer = -1); overload;
    procedure AddAltLine(const aAltValues: TKMCardinalArray);
    procedure TrimToFirstVariation;
    property Caption: UnicodeString read fCaption write fCaption;
    procedure Clear;
    procedure SetLineVisible(aLineID:Integer; aVisible:Boolean);
    property MaxLength: Cardinal read fMaxLength write fMaxLength;
    property MaxTime: Cardinal read fMaxTime write fMaxTime;
    property Lines[aIndex: Integer]: TKMGraphLine read GetLine;
    property LineCount:Integer read fCount;
    property Font: TKMFont read fFont write fFont;
    property LegendWidth: Word read fLegendWidth write fLegendWidth;
    property LegendCaption: String read fLegendCaption write fLegendCaption;
    property Peacetime: Cardinal read fPeaceTime write fPeaceTime;

    property SeparatorPos[aIndex: Integer]: Integer read GetSeparatorPos;
    property SeparatorColor: TColor4 read fSeparatorColor write fSeparatorColor;
    property SeparatorHeight: Byte read fSeparatorHeight write fSeparatorHeight;

    procedure AddSeparator(aPosition: Integer);
    procedure SetSeparatorPositions(aSeparatorPositions: TStringList);
    procedure ClearSeparators;

    property OnLegendClick: TObjectIntBoolEvent read fOnLegendClick write fOnLegendClick;

    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure Paint; override;
  end;

  PKMChart = ^TKMChart;

  //MinimapView relies on fMinimap and fViewport that provide all the data
  //MinimapView itself is just a painter
  TKMMinimapView = class(TKMControl)
  private
    fBevel: TKMBevel;
    fMinimap: TKMMinimap;
    fView: TKMViewport;
    fPaintWidth: Integer;
    fPaintHeight: Integer;
    fLeftOffset: Integer;
    fTopOffset: Integer;

    fMapTex: TTexture;
    fWidthPOT: Word;
    fHeightPOT: Word;

    fOnChange, fOnMinimapClick: TPointEvent;
    fShowLocs: Boolean;
    fLocRad: Byte;
    fClickableOnce: Boolean;
    procedure UpdateTexture;
    procedure ResizeMinimap;
  protected
    procedure SetAnchors(aValue: TKMAnchorsSet); override;
  public
    OnLocClick: TIntegerEvent;

    constructor Create(aMinimap: TKMMinimap; aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aWithBevel: Boolean = False);

    function LocalToMapCoords(X,Y: Integer): TKMPoint;
    function MapCoordsToLocal(X,Y: Single; const Inset: ShortInt = 0): TKMPoint;
    procedure UpdateSizes;
    procedure SetViewport(aViewport: TKMViewport);
    property ShowLocs: Boolean read fShowLocs write fShowLocs;
    property ClickableOnce: Boolean read fClickableOnce write fClickableOnce;
    property OnChange: TPointEvent write fOnChange;
    property OnMinimapClick: TPointEvent read fOnMinimapClick write fOnMinimapClick;

    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;


  function MakeListRow(const aCaption: array of String; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption, aHint: array of String; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption, aHint: array of string; const aColor: array of TColor4; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aColorHighlight: array of TColor4; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aPic: array of TKMPic; aTag: Integer = 0): TKMListRow; overload;


implementation
uses
  {$IFDEF MSWindows} Windows, {$ENDIF}
  {$IFDEF Unix} LCLIntf, LCLType, {$ENDIF}
  SysUtils, StrUtils, Math,
  Clipbrd,
  KromUtils,
  KM_System,
  KM_MinimapGame,
  KM_Resource, KM_ResSprites, KM_ResSound, KM_ResTexts,
  KM_Render, KM_RenderTypes,
  KM_Sound, KM_CommonUtils, KM_UtilsExt;


const
  CLICK_HOLD_TIME_THRESHOLD = 200; // Time period, determine delay between mouse down and 1st click hold events
  WARE_ROW_HEIGHT = 21;

type
  TKMCursorDir = (cdNone = 0, cdForward = 1, cdBack = -1);


function MakeListRow(const aCaption: array of String; aTag: Integer = 0): TKMListRow;
var
  I: Integer;
begin
  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := $FFFFFFFF;
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption, aHint: array of String; aTag: Integer = 0): TKMListRow;
var
  I: Integer;
begin
  Assert(Length(aCaption) = Length(aHint));
  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].CellHint := aHint[I];
    Result.Cells[I].Color := $FFFFFFFF;
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; aTag: Integer = 0): TKMListRow;
var I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption, aHint: array of string; const aColor: array of TColor4; aTag: Integer = 0): TKMListRow;
var I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));
  Assert(Length(aCaption) = Length(aHint));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].CellHint := aHint[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aColorHighlight: array of TColor4; aTag: Integer = 0): TKMListRow;
var
  I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));
  Assert(Length(aCaption) = Length(aColorHighlight));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].HighlightColor := aColorHighlight[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aPic: array of TKMPic;
                     aTag: Integer = 0): TKMListRow;
var
  I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));
  Assert(Length(aCaption) = Length(aPic));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].Pic := aPic[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function IsSelecting(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := (ssShift in Shift) and (Key <> VK_SHIFT);
end;


function GetCursorDir(aKey: Word): TKMCursorDir;
begin
  case aKey of
    VK_LEFT:  Result := cdBack;
    VK_RIGHT: Result := cdForward;
    else      Result := cdNone;
  end;
end;


{ TKMControl }
constructor TKMControl.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLayer: Integer = 0);
begin
  inherited Create;

  Scale         := 1;
  Hitable       := True; //All controls can be clicked by default
  CanChangeEnable := True; //All controls can change enable status by default
  fLeft         := aLeft;
  fTop          := aTop;
  fWidth        := aWidth;
  fHeight       := aHeight;

  fBaseWidth    := aWidth;
  fBaseHeight   := aHeight;

  Anchors       := [anLeft, anTop];
  State         := [];
  fEnabled      := True;
  fVisible      := True;
  Tag           := 0;
  fHint         := '';
  fHintBackColor := TKMColor4f.New(0, 0, 0, 0.7); // Black with 0.7 alpha
  fMouseWheelStep := 1;
  fPaintLayer   := aPaintLayer;
  fControlIndex := -1;
  AutoFocusable := True;
  HandleMouseWheelByDefault := True;
  fLastClickPos := KMPOINT_ZERO;
  fIsHitTestUseDrawRect := False;
  DebugHighlight := False;

//  fKeyPressList := TList<TKMKeyPress>.Create;

  if aParent <> nil then
  begin
    fID := aParent.fMasterControl.GetNextCtrlID;
    aParent.fMasterControl.fMaxPaintLayer := Max(aPaintLayer, aParent.fMasterControl.fMaxPaintLayer);
  end else if Self is TKMPanel then
    fID := 0;

  //Parent will be Nil only for master Panel which contains all the controls in it
  fParent   := aParent;
  if aParent <> nil then
    fControlIndex := aParent.AddChild(Self);
end;

destructor TKMControl.Destroy;
begin
//  fKeyPressList.Free;

  inherited;
end;


procedure TKMControl.DebugKeyDown(Key: Word; Shift: TShiftState);
var
  amt: Byte;
begin
  if MODE_DESIGN_CONTROLS then
  begin
    amt := 1;
    if ssShift in Shift then amt := 10;
    if ssAlt in Shift then amt := 100;

    if Key = VK_LEFT  then fLeft   := fLeft - amt;
    if Key = VK_RIGHT then fLeft   := fLeft + amt;
    if Key = VK_UP    then fTop    := fTop  - amt;
    if Key = VK_DOWN  then fTop    := fTop  + amt;
    if Key = VK_HOME  then fWidth  := fWidth  + amt;
    if Key = VK_END   then fWidth  := fWidth  - amt;
    if Key = VK_PRIOR then fHeight := fHeight  + amt;
    if Key = VK_NEXT  then fHeight := fHeight  - amt;
  end;
end;


function TKMControl.KeyDown(Key: Word; Shift: TShiftState): Boolean;
//var
//  keyPress: TKMKeyPress;
begin
//  if fKeyPressList.Count = 0 then
//    keyPress.Time := TimeGetUSec
//  else
//    keyPress.Time := TimeSinceUSec(fKeyPressList[0].Time);

//  keyPress.Key := Key;
//  keyPress.C := Char(Key);
//  keyPress.Kind := kpkDown;
//  fKeyPressList.Add(keyPress);

  Result := MODE_DESIGN_CONTROLS;

  if Assigned(fOnKeyDown) then
    Result := fOnKeyDown(Self, Key, Shift);

  // Exit if control handlers handle the event
  if Result then
    Exit;

  // Unfocus focused control without AutoFocusable flag on Esc key
  if IsFocused and not AutoFocusable and (Key = VK_ESCAPE) then
    Unfocus;
end;


procedure TKMControl.KeyPress(Key: Char);
//var
//  I: Integer;
//  keyPress: TKMKeyPress;
begin
//  if fKeyPressList.Count = 0 then
//    keyPress.Time := TimeGetUSec
//  else
//    keyPress.Time := TimeSinceUSec(fKeyPressList[0].Time);
////  keyPress.Key := 0;
//  keyPress.C := Key;
//  keyPress.Kind := kpkPress;
//
//  fKeyPressList.Add(keyPress);

//  gLog.AddTime('KeyPressList cnt ' + IntToStr(fKeyPressList.Count));
//  for I := 0 to fKeyPressList.Count - 1 do
//    gLog.AddTime(fKeyPressList[I].ToString);

  //Could be something common
end;


function TKMControl.CanFocusNext: Boolean;
begin
  Result := True;
end;


function TKMControl.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
  if (Key = VK_TAB) and CanFocusNext and IsFocused then
  begin
    Parent.FocusNext;
    Exit(True);
  end;

  if Assigned(fOnKeyUp) then
    Result := fOnKeyUp(Self, Key, Shift);
end;


procedure TKMControl.ResetClickHoldMode;
begin
  if Self <> nil then // Could be nil when control is destroyes already, f.e. on game (map) exit
  begin
    fClickHoldMode := False;
    fClickHoldHandled := False;
  end;
end;


procedure TKMControl.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //if Assigned(fOnMouseDown) then fOnMouseDown(Self); { Unused }
  fClickHoldMode := True;
  fTimeOfLastMouseDown := TimeGet;
  fLastMouseDownButton := Button;
end;


procedure TKMControl.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  //if Assigned(fOnMouseOver) then fOnMouseOver(Self); { Unused }
  if (csDown in State) then
  begin
    //Update fClickHoldMode
    if InRange(X, AbsLeft, AbsRight) and InRange(Y, AbsTop, AbsBottom) then
      fClickHoldMode := True
    else
      fClickHoldMode := False;
  end;
end;


procedure TKMControl.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  clickHoldHandled: Boolean;
begin
  //if Assigned(fOnMouseUp) then OnMouseUp(Self); { Unused }

  if (csDown in State) then
  begin
    State := State - [csDown];
    clickHoldHandled := fClickHoldHandled;
    ResetClickHoldMode;
    //Send Click events
    if not clickHoldHandled then // Do not send click event, if it was handled already while in click hold mode
      DoClick(X, Y, Shift, Button);
    end;
  // No code is allowed after DoClick, as control object could be destroyed,
  // that means we will modify freed memory, which will cause memory leaks
end;


function TKMControl.GetIDsStr: String;
begin
  if Self = nil then Exit('');

  Result := IntToStr(fID) + ' ' + fParent.GetIDsStr;
end;


function TKMControl.GetHint: UnicodeString;
begin
  Result := fHint;
end;


function TKMControl.GetHintFont: TKMFont;
begin
  Result := fntMonospaced; // Should be actually overridden in the ancestors
end;


function TKMControl.IsHintSelected: Boolean;
begin
  Result := False;
end;


function TKMControl.GetHintKind: TKMHintKind;
begin
  Result := hkControl;
end;


procedure TKMControl.SetHintBackColor(const aValue: TKMColor4f);
begin
  fHintBackColor := aValue;
end;


function TKMControl.GetHintBackColor: TKMColor4f;
begin
  Result := fHintBackColor;
end;


function TKMControl.GetHintBackRect: TKMRect;
begin
  Result := KMRECT_ZERO;
end;


function TKMControl.GetHintTextColor: TColor4;
begin
  Result := icWhite;
end;


function TKMControl.GetHintTextOffset: TKMPoint;
begin
  Result := KMPOINT_ZERO;
end;


procedure TKMControl.SetHint(const aHint: UnicodeString);
begin
  //fHint := StringReplace(aHint, '|', ' ', [rfReplaceAll]); //Not sure why we were need to replace | here...
  fHint := aHint;
end;


procedure TKMControl.SetPaintLayer(aPaintLayer: Integer);
begin
  fPaintLayer := aPaintLayer;
end;


function TKMControl.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := HandleMouseWheelByDefault            //Controls handle MouseWheel by default
    and Parent.DoPanelHandleMouseWheelByDefault; //But their parent could override this
end;


procedure TKMControl.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  if Assigned(fOnMouseWheel) then
    fOnMouseWheel(Self, WheelSteps, aHandled)
  else
  if fParent <> nil then
  begin
    if DoHandleMouseWheelByDefault then
      fParent.MouseWheel(Sender, WheelSteps, aHandled)
    else
      aHandled := False;
  end
  else
    aHandled := False;
end;


//fVisible is checked earlier
function TKMControl.HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): Boolean;
begin
  Result := False;
  if    (Hitable or aIncludeNotHitable)
    and (fEnabled or aIncludeDisabled) then
  begin
    //DrawRect could is restricted by parent panel size and also could be restricted with parent ScrollPanel
    //While outside of ScrollPanel its better to use Abs coordinates
    //since some childs could be outside of its parent borders for some reason
    if fIsHitTestUseDrawRect then
      Result := KMInRect(KMPoint(X,Y), GetDrawRect)
    else
      Result := InRange(X, AbsLeft, AbsRight)
            and InRange(Y, AbsTop, AbsBottom);
  end;
end;


{One common thing - draw childs for self}
procedure TKMControl.Paint;
var
  sColor: TColor4;
  tmp: TKMPoint;
  skipText: Boolean;
begin
  Inc(CtrlPaintCount);

  if SHOW_FOCUSED_CONTROL and (csFocus in State) then
    TKMRenderUI.WriteOutline(AbsLeft-2, AbsTop-2, Width+4, Height+4, 2, $FF00D0FF);

  if (SHOW_CONTROL_OVER or MODE_DESIGN_CONTROLS) and (csOver in State) then
    TKMRenderUI.WriteOutline(AbsLeft-2, AbsTop-2, Width+4, Height+4, 2, $FFFFD000);

  if SHOW_CONTROLS_ID then
  begin
    skipText := SKIP_RENDER_TEXT; //Save value
    SKIP_RENDER_TEXT := False; // Force Render debug data
    TKMRenderUI.WriteText(AbsLeft+1, AbsTop, fWidth, IntToStr(fID), TKMFont(DEBUG_TEXT_FONT_ID), taLeft);
    SKIP_RENDER_TEXT := skipText; // Restore value
  end;

  if DebugHighlight then
    TKMRenderUI.WriteOutline(AbsLeft-2, AbsTop-2, Width+4, Height+4, 2, icRed);

  if not SHOW_CONTROLS_OVERLAY then Exit;

  sColor := $00000000;

  if Self is TKMPanel then sColor := $200000FF;

  if Self is TKMLabel then
  begin //Special case for aligned text
    tmp := TKMLabel(Self).TextSize;
    TKMRenderUI.WriteShape(TKMLabel(Self).TextLeft, AbsTop, tmp.X, tmp.Y, $4000FFFF, $80FFFFFF);
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, fWidth, fHeight, 1, $FFFFFFFF);
    TKMRenderUI.WriteShape(AbsLeft-3, AbsTop-3, 6, 6, sColor or $FF000000, $FFFFFFFF);
    Exit;
  end;

  if Self is TKMLabelScroll then
  begin //Special case for aligned text
    tmp := TKMLabelScroll(Self).TextSize;
    TKMRenderUI.WriteShape(TKMLabelScroll(Self).TextLeft, AbsTop, tmp.X, tmp.Y, $4000FFFF, $80FFFFFF);
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, fWidth, fHeight, 1, $FFFFFFFF);
    TKMRenderUI.WriteShape(AbsLeft-3, AbsTop-3, 6, 6, sColor or $FF000000, $FFFFFFFF);
    Exit;
  end;

  if Self is TKMImage      then sColor := $2000FF00;
  if Self is TKMImageStack then sColor := $2080FF00;
  if Self is TKMCheckBox   then sColor := $20FF00FF;
  if Self is TKMTrackBar   then sColor := $2000FF00;
  if Self is TKMCostsRow   then sColor := $2000FFFF;
  if Self is TKMRadioGroup then sColor := $20FFFF00;

  if csOver in State then sColor := sColor OR $30000000; //Highlight on mouse over

  TKMRenderUI.WriteShape(AbsLeft, AbsTop, fWidth, fHeight, sColor, $FFFFFFFF);
  TKMRenderUI.WriteShape(AbsLeft-3, AbsTop-3, 6, 6, sColor or $FF000000, $FFFFFFFF);
end;


function TKMControl.PaintingBaseLayer: Boolean;
begin
  Result := (fParent = nil) or (fParent.fMasterControl.fCurrentPaintLayer = 0);
end;


function TKMControl.GetMasterPanel: TKMPanel;
begin
  Result := Parent.MasterControl.MasterPanel;
end;


{Shortcuts to Controls properties}
procedure TKMControl.SetAbsLeft(aValue: Integer);
begin
  if Parent = nil then
    Left := aValue
  else
    Left := Round((aValue - Parent.AbsLeft) / Parent.Scale);
end;

procedure TKMControl.SetAbsTop(aValue: Integer);
begin
  if Parent = nil then
    Top := aValue
  else
    Top := Round((aValue - Parent.AbsTop) / Parent.Scale);
end;

//GetAbsCoordinates
function TKMControl.GetAbsBottom: Integer;
begin
  Result := GetAbsTop + GetHeight;
end;

function TKMControl.GetAbsLeft: Integer;
begin
  if Parent = nil then
    Result := Round(fLeft)
  else
    Result := Round(fLeft * Parent.Scale) + Parent.GetAbsLeft;
end;

function TKMControl.GetAbsRight: Integer;
begin
  Result := GetAbsLeft + GetWidth;
end;

function TKMControl.GetAbsTop: Integer;
begin
  if Parent = nil then
    Result := Round(fTop)
  else
    Result := Round(fTop * Parent.Scale) + Parent.GetAbsTop;
end;
//-------------------------------

//AbsDrawCoordinates
function TKMControl.GetAbsDrawLeft: Integer;
begin
  Result := GetAbsLeft;
end;

function TKMControl.GetAbsDrawTop: Integer;
begin
  Result := GetAbsTop;
end;

function TKMControl.GetAbsDrawRight: Integer;
begin
  Result := GetAbsRight;
end;

function TKMControl.GetAbsDrawBottom: Integer;
begin
  Result := GetAbsBottom;
end;
//-------------------------------

function TKMControl.GetLeft: Integer;
begin
  Result := Round(fLeft)
end;

function TKMControl.GetTop: Integer;
begin
  Result := Round(fTop)
end;

function TKMControl.GetBottom: Integer;
begin
  Result := GetTop + GetHeight;
end;

function TKMControl.GetRight: Integer;
begin
  Result := GetLeft + GetWidth;
end;


procedure TKMControl.SetLeft(aValue: Integer);
begin
  fLeft := aValue;

  if Assigned(fOnPositionSet) then
    fOnPositionSet(Self);
end;

procedure TKMControl.SetTop(aValue: Integer);
begin
  fTop := aValue;

  if Assigned(fOnPositionSet) then
    fOnPositionSet(Self);
end;

function TKMControl.GetHeight: Integer;
begin
  Result := fHeight;
end;

function TKMControl.GetWidth: Integer;
begin
  Result := fWidth;
end;

function TKMControl.GetCenter: TKMPoint;
begin
  Result := KMPoint(GetLeft + (GetWidth div 2), GetTop + (GetHeight div 2));
end;


function TKMControl.GetSelfAbsLeft: Integer;
begin
  Result := AbsLeft;
end;


function TKMControl.GetSelfAbsTop: Integer;
begin
  Result := AbsTop;
end;


function TKMControl.GetSelfHeight: Integer;
begin
  Result := fHeight;
end;


function TKMControl.GetSelfWidth: Integer;
begin
  Result := fWidth;
end;


procedure TKMControl.SetTopF(aValue: Single);
begin
  //Call child classes SetTop methods
  SetTop(Round(aValue));

  //Assign actual FP value
  fTop := aValue;
end;

procedure TKMControl.SetLeftF(aValue: Single);
begin
  //Call child classes SetTop methods
  SetLeft(Round(aValue));

  //Assign actual FP value
  fLeft := aValue;
end;


function TKMControl.GetControlRect: TKMRect;
begin
  Result := KMRect(Left, Top, Left + Width, Top + Height);
end;


function TKMControl.GetControlAbsRect: TKMRect;
begin
  Result := KMRect(AbsLeft, AbsTop, AbsRight, AbsBottom);
end;


function TKMControl.GetIsFocused: Boolean;
begin
  Result := csFocus in State;
end;


function TKMControl.GetIsClickable: Boolean;
begin
  Result := Visible and Enabled;
end;


//Overriden in child classes
procedure TKMControl.SetHeight(aValue: Integer);
var
  oldH: Integer;
begin
  oldH := fHeight;
  fHeight := aValue;

  if (oldH <> fHeight) and Assigned(fOnHeightChange) then
    fOnHeightChange(Self, fHeight);

  if Assigned(fOnSizeSet) then
    fOnSizeSet(Self);
end;

//Overriden in child classes
procedure TKMControl.SetWidth(aValue: Integer);
var
  oldW: Integer;
begin
  oldW := fHeight;
  fWidth := aValue;

  if (oldW <> fWidth) and Assigned(fOnWidthChange) then
    fOnWidthChange(Self, fWidth);

  if Assigned(fOnSizeSet) then
    fOnSizeSet(Self);
end;


function TKMControl.GetDrawRect: TKMRect;
begin
  if fParent <> nil then
  begin
    Result := fParent.GetDrawRect;
    if Result <> KMRECT_INVALID_TILES then
      Result := KMRectIntersect(Result, AbsDrawLeft, AbsDrawTop, AbsDrawRight, AbsDrawBottom);
  end else
    Result := KMRect(AbsDrawLeft, AbsDrawTop, AbsDrawRight, AbsDrawBottom);
end;


//Let the control know that it was clicked to do its internal magic
procedure TKMControl.DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //Note that we process double-click separately (actual sequence is Click + Double-Click)
  //because we would not like to delay Click just to make sure it is single.
  //On the ther hand it does no harm to call Click first
  if (Button = mbLeft)
    and Assigned(fOnDoubleClick)
    and KMSamePoint(fLastClickPos, KMPoint(X,Y))
    and (TimeSince(fTimeOfLastClick) <= GetDoubleClickTime) then
  begin
    fTimeOfLastClick := 0;
    fOnDoubleClick(Self);
  end
  else
  begin
    if (Button = mbLeft) and Assigned(fOnDoubleClick) then
    begin
      fTimeOfLastClick := TimeGet;
      fLastClickPos := KMPoint(X,Y);
    end;

    if Assigned(fOnClickShift) then
      fOnClickShift(Self, Shift)
    else
    if (Button = mbLeft) and Assigned(fOnClick) then
      fOnClick(Self)
    else
    if (Button = mbRight) and Assigned(fOnClickRight) then
      fOnClickRight(Self, X, Y);
  end;
end;


procedure TKMControl.DoClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
begin
  aHandled := False;
  //Let descendants override this method
end;


// Check Control including all its Parents to see if Control is actually displayed/visible
function TKMControl.GetVisible: Boolean;
begin
  if Self = nil then Exit(False);

  Result := fVisible and ((Parent = nil) or Parent.Visible);
end;


function TKMControl.GetIsPainted: Boolean;
begin
  Result := GetVisible;
end;


procedure TKMControl.SetEnabled(aValue: Boolean);
var
  oldEnabled: Boolean;
begin
  if not CanChangeEnable then Exit; //Change enability is blocked

  oldEnabled := fEnabled;
  fEnabled := aValue;

  // Only swap focus if enability changed
  if (oldEnabled <> Enabled) and (Focusable or (Self is TKMPanel)) then
    MasterParent.fMasterControl.UpdateFocus(Self);

  UpdateEnableStatus;
end;


procedure TKMControl.SetFocusable(const aValue: Boolean);
var
  oldFocusable: Boolean;
begin
  oldFocusable := fFocusable;

  fFocusable := aValue;

  // Update focus if Focusable was changed
  if oldFocusable <> fFocusable then
    Parent.MasterControl.UpdateFocus(Self);
end;


procedure TKMControl.SetAnchors(aValue: TKMAnchorsSet);
begin
  fAnchors := aValue;
end;


procedure TKMControl.SetVisible(aValue: Boolean);
var
  oldVisible: Boolean;
begin
  oldVisible := fVisible;
  fVisible := aValue;

  //Swap focus and UpdateVisibility only if visibility changed
  if (oldVisible <> fVisible) then
  begin
    if Focusable or (Self is TKMPanel) then
      MasterParent.fMasterControl.UpdateFocus(Self);

    UpdateVisibility;
  end;
end;


procedure TKMControl.UpdateState(aTickCount: Cardinal);
var
  sameMouseBtn: Boolean;
begin
  if (csDown in State) and fClickHoldMode and (TimeSince(fTimeOfLastMouseDown) > CLICK_HOLD_TIME_THRESHOLD)  then
  begin
    sameMouseBtn := False;
    case fLastMouseDownButton of
      mbLeft:   sameMouseBtn := (GetKeyState(VK_LBUTTON) < 0);
      mbRight:  sameMouseBtn := (GetKeyState(VK_RBUTTON) < 0);
    end;
    if sameMouseBtn then
    begin
      DoClickHold(Self, fLastMouseDownButton, fClickHoldHandled);
      if Assigned(fOnClickHold) then
        fOnClickHold(Self, fLastMouseDownButton, fClickHoldHandled);
    end else
      ResetClickHoldMode; //Can happen if user alt-tab from game window while holding MB. Reset Click Hold mode then
  end;

end;


procedure TKMControl.UpdateVisibility;
begin
  if Assigned(fOnChangeVisibility) then
    fOnChangeVisibility(Self, fVisible);
  //Let descendants override this method
end;


procedure TKMControl.UpdateEnableStatus;
begin
  if Assigned(fOnChangeEnableStatus) then
    fOnChangeEnableStatus(Self, fEnabled);
  //Let descendants override this method
end;


procedure TKMControl.FocusChanged(aFocused: Boolean);
begin
  //Let descendants override this method
end;


//procedure TKMControl.ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
//begin
//  //Let descendants override this method
//end;
//
//
//procedure TKMControl.ControlMouseUp(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
//begin
//  //Let descendants override this method
//end;


procedure TKMControl.Enable;  begin SetEnabled(True);  end; //Overrides will be set too
procedure TKMControl.Disable; begin SetEnabled(False); end;


// Show up entire branch in which control resides
procedure TKMControl.Show;
begin
  if Parent <> nil then Parent.Show;
  Visible := True;
end;


procedure TKMControl.ToggleVisibility;
begin
  Visible := not Visible;
end;


procedure TKMControl.Hide;
begin
  Visible := False;
end;


procedure TKMControl.DoSetVisible;
begin
  Visible := True;
end;


procedure TKMControl.AnchorsCenter;
begin
  Anchors := [];
end;


procedure TKMControl.AnchorsStretch;
begin
  Anchors := [anLeft, anTop, anRight, anBottom];
end;


procedure TKMControl.Focus;
begin
  if not IsFocused and Focusable then
  begin
    // Reset master control focus
    Parent.fMasterControl.CtrlFocus := nil;
    Parent.FocusedControlIndex := ControlIndex;
    Parent.fMasterControl.CtrlFocus := Self;
//    Parent.fMasterControl.UpdateFocus(Parent); // It looks like we can manually set focus, no need for update procedure
  end;
end;


procedure TKMControl.Unfocus;
begin
  Parent.fMasterControl.CtrlFocus := nil;
end;


function TKMControl.MasterParent: TKMPanel;
var
  P: TKMPanel;
begin
  if not (Self is TKMPanel) then
    P := Parent
  else
    P := TKMPanel(Self);

  while P.Parent <> nil do
    P := P.Parent;
  Result := P;
end;


procedure TKMControl.SetPosCenterW;
begin
  Left := (Parent.Width - Width) div 2;
end;


procedure TKMControl.SetPosCenterH;
begin
  Top := (Parent.Height - Height) div 2;
end;


procedure TKMControl.SetPosCenter;
begin
  SetPosCenterW;
  SetPosCenterH;
end;


function TKMControl.ToStr: string;
begin
  if Self = nil then Exit('nil');
  
  Result := Format('ID=%d ParentID=%d Class=%s AbsPos: (%d;%d) Pos: (%d;%d) Sizes: [%d;%d]',
                   [fID, Parent.ID, ClassName, AbsLeft, AbsTop, Left, Top, fWidth, fHeight]);
end;


{ TKMPanel } //virtual panels that contain child items
constructor TKMPanel.Create(aParent: TKMMasterControl; aLeft, aTop, aWidth, aHeight: Integer; aPaintLevel: Integer = 0);
begin
  inherited Create(nil, aLeft, aTop, aWidth, aHeight, aPaintLevel);

  fMasterControl := aParent;
  aParent.fMasterPanel := Self;
  Init;
end;


constructor TKMPanel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLevel: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLevel);

  fMasterControl := aParent.fMasterControl;
  Init;
end;


procedure TKMPanel.Init;
begin
  ResetFocusedControlIndex;
  PanelHandleMouseWheelByDefault := True; //Panels handle mousewheel by default
end;


procedure TKMPanel.ResetFocusedControlIndex;
begin
  FocusedControlIndex := -1;
end;


destructor TKMPanel.Destroy;
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    Childs[I].Free;

  inherited;
end;


function TKMPanel.FindFocusableControl(aFindNext: Boolean): TKMControl;
var
  I, ctrlToFocusI: Integer;
begin
  Result := nil;
  ctrlToFocusI := -1;
  for I := 0 to ChildCount - 1 do
    if fMasterControl.IsAutoFocusAllowed(Childs[I]) and (
      (FocusedControlIndex = -1)                          // If FocusControl was not set (no focused element on panel)
      or (FocusedControlIndex = Childs[I].ControlIndex) // We've found last focused Control
      or (ctrlToFocusI <> -1)) then                         // We did find last focused Control on previos iterations
    begin
      //Do we need to find next focusable control ?
      if aFindNext and (ctrlToFocusI = -1)
        //FocusedControlIndex = -1 means there is no focus on this panel. Then we need to focus on first good control
        and (FocusedControlIndex <> -1) then
      begin
        ctrlToFocusI := I;
        Continue;
      end else begin
        Result := Childs[I]; // We find Control to focus on, then exit
        Exit;
      end;
    end;

  // If we did not find Control to focus on, try to find in the first controls of Panel (let's cycle the search)
  if ctrlToFocusI <> -1 then
  begin
    // We will try to find it until the same Control, that we find before in previous For cycle
    for I := 0 to ctrlToFocusI do // So if there will be no proper controls, then set focus again to same control with I = CtrlToFocusI
      if fMasterControl.IsAutoFocusAllowed(Childs[I]) then
      begin
        Result := Childs[I];
        Exit;
      end;
  end;
end;


//Focus next focusable control on this Panel
procedure TKMPanel.FocusNext;
var
  ctrl: TKMControl;
begin
  if InRange(FocusedControlIndex, 0, ChildCount - 1) then
  begin
    ctrl := FindFocusableControl(True);
    if ctrl <> nil then
      FocusedControlIndex := ctrl.ControlIndex; // update FocusedControlIndex to let fCollection.UpdateFocus focus on it
    //Need to update Focus only through UpdateFocus
    fMasterControl.UpdateFocus(Self);
  end;
end;


procedure TKMPanel.Enlarge(aChild: TKMControl);
begin
  if Self = nil then Exit;

  fLeft := Left + Min(0, aChild.Left);
  fTop := Top + Min(0, aChild.Top);
  fWidth := Width - Min(0, aChild.Left);
  fHeight := Height - Min(0, aChild.Top);
  fWidth := Width + Max(0, aChild.Right - Right);
  fHeight := Height + Max(0, aChild.Bottom - Bottom);

  fParent.Enlarge(Self);
end;


function TKMPanel.AddChild(aChild: TKMControl): Integer;
begin
  //Descendants of TKMScrollPanel should all use DrawRect for HitTest
  aChild.fIsHitTestUseDrawRect := fIsHitTestUseDrawRect;

  if ChildCount >= Length(Childs) then
    SetLength(Childs, ChildCount + 16);

  Childs[ChildCount] := aChild;
  Result := ChildCount;
  Inc(ChildCount);
end;


procedure TKMPanel.SetCanChangeEnable(aEnable: Boolean; aExceptControls: array of TKMControlClass; aAlsoSetEnable: Boolean = True);
var
  I, J: Integer;
  skipChild: Boolean;
begin
  if aEnable and aAlsoSetEnable then
    Enabled := aEnable;
  for I := 0 to ChildCount - 1 do
  begin
    if Childs[I] is TKMPanel then
      TKMPanel(Childs[I]).SetCanChangeEnable(aEnable, aExceptControls, aAlsoSetEnable)
    else begin
      skipChild := False;
      for J := Low(aExceptControls) to High(aExceptControls) do
        if Childs[I] is aExceptControls[J] then
        begin
          skipChild := True;
          Break;
        end;

      if skipChild then
        Continue;

      //Unblock first to be able to change Enable status
      if aEnable then
        Childs[I].CanChangeEnable := aEnable;

      if aAlsoSetEnable then
      begin
        Childs[I].Enabled := aEnable;
        //Set fEnabledVisually for TKMButtonFlat. They looks better in that case
        if Childs[I] is TKMButtonFlat then
          Childs[I].fEnabledVisually := not aEnable;
      end;

      if not aEnable then
        Childs[I].CanChangeEnable := aEnable;
    end;
  end;
  if not aEnable and aAlsoSetEnable then
    Enabled := aEnable;
end;


procedure TKMPanel.SetHeight(aValue: Integer);
var
  I, diff: Integer;
begin
  for I := 0 to ChildCount - 1 do
  begin
    diff := aValue - fHeight;

    if (anTop in Childs[I].Anchors) and (anBottom in Childs[I].Anchors) then
      Childs[I].Height := Childs[I].Height + diff
    else
    if anTop in Childs[I].Anchors then
      //Do nothing
    else
    if anBottom in Childs[I].Anchors then
      Childs[I].SetTopF(Childs[I].fTop + diff)
    else
    begin
      // Fit into parent panel
      if Childs[I].FitInParent then
      begin
        // Child base is bigger, than parent is going to be
        if aValue < Childs[I].BaseHeight then
        begin
          Childs[I].Height := aValue;
          Childs[I].SetTopF(0);
        end
        else
        // Child base is smaller, restore it BaseHeight
        begin
          Childs[I].Height := Childs[I].BaseHeight;
          // Use 'centered' position for now
          // We could try to save or to set 'baseTop as a float value of total parent height' in the future
          Childs[I].SetTopF((aValue - Childs[I].Height) / 2);
        end;
      end
      else
        Childs[I].SetTopF(Childs[I].fTop + diff / 2);
    end;
  end;

  inherited;
end;


procedure TKMPanel.SetWidth(aValue: Integer);
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    if (anLeft in Childs[I].Anchors) and (anRight in Childs[I].Anchors) then
      Childs[I].Width := Childs[I].Width + (aValue - fWidth)
    else
    if anLeft in Childs[I].Anchors then
      //Do nothing
    else
    if anRight in Childs[I].Anchors then
      Childs[I].SetLeftF(Childs[I].fLeft + (aValue - fWidth))
    else
    begin
      // Fit into parent panel
      if Childs[I].FitInParent then
      begin
        // Child base is bigger, than parent is going to be
        if aValue < Childs[I].BaseWidth then
        begin
          Childs[I].Width := aValue;
          Childs[I].SetLeftF(0);
        end
        else
          // Child base is smaller, restore it BaseWidth
        begin
          Childs[I].Width := Childs[I].BaseWidth;
          // Use 'centered' position for now
          // We could try to save or to set 'baseLeft as a float value of total parent width' in the future
          Childs[I].SetLeftF((aValue - Childs[I].Width) / 2);
        end;
      end
      else
        Childs[I].SetLeftF(Childs[I].fLeft + (aValue - fWidth) / 2);
    end;

  inherited;
end;


//procedure TKMPanel.ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
//var
//  I: Integer;
//begin
//  inherited;
//  for I := 0 to ChildCount - 1 do
//    Childs[I].ControlMouseDown(Sender, X, Y, Shift, Button);
//end;
//
//
//procedure TKMPanel.ControlMouseUp(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
//var
//  I: Integer;
//begin
//  inherited;
//  for I := 0 to ChildCount - 1 do
//    Childs[I].ControlMouseUp(Sender, X, Y, Shift, Button);
//end;


procedure TKMPanel.UpdateState(aTickCount: Cardinal);
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    Childs[I].UpdateState(aTickCount);
end;


procedure TKMPanel.UpdateVisibility;
var
  I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    Childs[I].UpdateVisibility;
end;


procedure TKMPanel.UpdateEnableStatus;
var
  I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    Childs[I].UpdateEnableStatus;
end;


function TKMPanel.DoPanelHandleMouseWheelByDefault: Boolean;
begin
  Result := PanelHandleMouseWheelByDefault //Panels handle mousewheel by default
    and ((Parent = nil) or Parent.DoPanelHandleMouseWheelByDefault); //But their parents could override this
end;


procedure TKMPanel.Paint;
begin
  inherited Paint;
end;


{Panel Paint means to Paint all its childs}
procedure TKMPanel.PaintPanel(aPaintLayer: Integer);
begin
  Paint;
  DoPaint(aPaintLayer);
end;


procedure TKMPanel.DoPaint(aPaintLayer: Integer);
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    if Childs[I].fVisible then
    begin
      if Childs[I] is TKMPanel then
        TKMPanel(Childs[I]).PaintPanel(aPaintLayer)
      else if (Childs[I].fPaintLayer = aPaintLayer) then
        Childs[I].Paint;
    end;
end;


// Check if specified aChar is allowed for specified aAllowedChars type
function IsCharAllowed(aChar: WideChar; aAllowedChars: TKMAllowedChars): Boolean;
const
  HexDigits:        TSetOfAnsiChar = [#48..#57,#65..#70,#97..#102]; //0..9 A..F a..f
  Ansi7Chars:       TSetOfAnsiChar = [#32..#123,#125..#126]; //except | character
  NonFileChars:     TSetOfAnsiChar = [#0 .. #31, '<', '>', #176, '|', '"', '\', '/', ':', '*', '?'];
  NonTextCharsWEOL: TSetOfAnsiChar = [#0 .. #31, #176, '|']; //° has negative width so acts like a backspace in KaM fonts
  NonTextChars:     TSetOfAnsiChar = [#0 .. #31, #176]; //° has negative width so acts like a backspace in KaM fonts
begin
  Result := not ((aAllowedChars = acDigits)   and not InRange(Ord(aChar), 48, 57)
              or (aAllowedChars = acHex)      and not CharInSet(aChar, HexDigits)
              or (aAllowedChars = acANSI7)    and not CharInSet(aChar, Ansi7Chars)
              or (aAllowedChars = acFileName) and CharInSet(aChar, NonFileChars)
              or (aAllowedChars = acText)     and CharInSet(aChar, NonTextCharsWEOL)
              or (aAllowedChars = acAll)      and CharInSet(aChar, NonTextChars));
end;


{ TKMForm }
constructor TKMForm.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fHeaderHeight := 24;

  fButtonClose := TKMButtonFlat.Create(Self, aWidth - fHeaderHeight + 2, 2, fHeaderHeight-4, fHeaderHeight-4, 340, rxGui);
  fButtonClose.OnClick := FormCloseClick;
  fLabelCaption := TKMLabel.Create(Self, 0, 5, aWidth, fHeaderHeight, 'Form1', fntOutline, taCenter);
  fLabelCaption.Hitable := False;
end;


procedure TKMForm.FormCloseClick(Sender: TObject);
begin
  Hide;

  if Assigned(OnClose) then
    OnClose(Self);
end;


function TKMForm.GetCaption: UnicodeString;
begin
  Result := fLabelCaption.Caption;
end;


procedure TKMForm.SetCaption(const aValue: UnicodeString);
begin
  fLabelCaption.Caption := aValue;
end;


function TKMForm.HitHeader(X, Y: Integer): Boolean;
begin
  Result := InRange(X - AbsLeft, 0, Width) and InRange(Y - AbsTop, 0, fHeaderHeight);
end;


procedure TKMForm.MouseDown(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  if HitHeader(X,Y) then
  begin
    fDragging := True;
    fOffsetX := X - AbsLeft;
    fOffsetY := Y - AbsTop;
  end;

  MouseMove(X, Y, Shift);
end;


procedure TKMForm.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;

  if fDragging and (csDown in State) then
  begin
    AbsLeft := EnsureRange(X - fOffsetX, 0, MasterParent.Width - Width);
    AbsTop := EnsureRange(Y - fOffsetY, 0, MasterParent.Height - Height);

    if Assigned(OnMove) then
      OnMove(Self);
  end;
end;


procedure TKMForm.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X,Y,Shift);

end;


procedure TKMForm.PaintPanel(aPaintLayer: Integer);
begin
  TKMRenderUI.WriteShadow(AbsLeft, AbsTop, Width, Height, 15, $40000000);

  TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, 3, $FF000000);
  TKMRenderUI.WriteOutline(AbsLeft+1, AbsTop+1, Width-2, Height-2, 1, $FF80FFFF);

  inherited;
end;


{ TKMBevel }
constructor TKMBevel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);

  SetDefBackAlpha;
  SetDefEdgeAlpha;
end;


procedure TKMBevel.SetDefBackAlpha;
begin
  BackAlpha := DEF_BACK_ALPHA; //Default value
end;


procedure TKMBevel.SetDefEdgeAlpha;
begin
  EdgeAlpha := DEF_EDGE_ALPHA; //Default value
end;


procedure TKMBevel.SetDefColor;
begin
  Color := COLOR3F_BLACK; //Default value
end;


procedure TKMBevel.Paint;
begin
  inherited;
  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height, Color, EdgeAlpha, BackAlpha, PaintingBaseLayer);
end;


{ TKMShape }
constructor TKMShape.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);

  LineWidth := 2;
end;


procedure TKMShape.Paint;
begin
  inherited;
  TKMRenderUI.WriteShape(AbsLeft, AbsTop, Width, Height, FillColor);
  TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, LineWidth, LineColor);
end;


{ TKMLabel }
constructor TKMLabel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString;
                            aFont: TKMFont; aTextAlign: TKMTextAlign; aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);
  fFont := aFont;
  fFontColor := $FFFFFFFF;
  fTextAlign := aTextAlign;
  fTextVAlign := tvaTop;
  fAutoWrap := False;
  fTabWidth := FONT_TAB_WIDTH;
  SetCaption(aCaption);
end;


//Same as above but with width/height ommitted, as in most cases we don't know/don't care
constructor TKMLabel.Create(aParent: TKMPanel; aLeft, aTop: Integer; const aCaption: UnicodeString; aFont: TKMFont;
                            aTextAlign: TKMTextAlign; aPaintLayer: Integer = 0);
begin
  Create(aParent, aLeft, aTop, 0, 0, aCaption, aFont, aTextAlign, aPaintLayer);
end;


function TKMLabel.TextLeft: Integer;
begin
  case fTextAlign of
    taLeft:   Result := AbsLeft;
    taCenter: Result := AbsLeft + Round((Width - fTextSize.X) / 2);
    taRight:  Result := AbsLeft + (Width - fTextSize.X);
    else      Result := AbsLeft;
  end;
end;


procedure TKMLabel.SetCaption(const aCaption: UnicodeString);
begin
  fCaption := aCaption;
  ReformatText;
end;


procedure TKMLabel.SetAutoCut(aValue: Boolean);
begin
  fAutoCut := aValue;
  ReformatText;
end;


procedure TKMLabel.SetAutoWrap(aValue: Boolean);
begin
  fAutoWrap := aValue;
  ReformatText;
end;


//Override usual hittest with regard to text alignment
function TKMLabel.HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): Boolean;
begin
  Result := (Hitable or aIncludeNotHitable)
            and InRange(X, TextLeft, TextLeft + fTextSize.X)
            and InRange(Y, AbsTop, AbsTop + Height);
end;


procedure TKMLabel.SetColor(aColor: Cardinal);
begin
  fCaption := StripColor(fCaption);
  Caption := WrapColor(fCaption, aColor);
end;


procedure TKMLabel.SetFont(const Value: TKMFont);
begin
  fFont := Value;
  ReformatText;
end;


//Existing EOLs should be preserved, and new ones added where needed
//Keep original intact incase we need to Reformat text once again
procedure TKMLabel.ReformatText;

  procedure Reformat;
  begin
    if fAutoWrap then
      fText := gRes.Fonts[fFont].WordWrap(fCaption, Width, True, False)
    else
      fText := fCaption;

    fTextSize := gRes.Fonts[fFont].GetTextSize(fText);
  end;

begin
  Reformat;
  // Automatically cut text symbol by symbol until it will fit into given sizes (width and height)
  if fAutoCut then
    while (Length(fCaption) > 0)
      and (((fTextSize.X > Width) and (Width > 0))
      or ((fTextSize.Y > Height) and (Height > 0))) do
    begin
      fCaption := Copy(fCaption, 1, Length(fCaption) - 1);
      Reformat;
    end;
end;


function TKMLabel.GetIsPainted: Boolean;
begin
  Result := inherited and (Length(fCaption) > 0 );
end;


// Send caption to render
procedure TKMLabel.Paint;
var
  t: Integer;
  col: Cardinal;
begin
  inherited;

  if fEnabled then col := FontColor
              else col := $FF888888;

  t := 0;
  if Height > 0 then
  begin
    case fTextVAlign of
      tvaNone,
      tvaTop:     ;
      tvaMiddle:  t := (Height - fTextSize.Y) div 2;
      tvaBottom:  t := Height - fTextSize.Y;
    end;
  end;

  TKMRenderUI.WriteText(AbsLeft, AbsTop + t, Width, fText, fFont, fTextAlign, col, False, False, False, fTabWidth, PaintingBaseLayer);

  if fStrikethrough then
    TKMRenderUI.WriteShape(TextLeft, AbsTop + fTextSize.Y div 2 - 2, fTextSize.X, 3, col, $FF000000);
end;


{ TKMLabelScroll }
constructor TKMLabelScroll.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aCaption, aFont, aTextAlign);
  SmoothScrollToTop := 0; //Disabled by default
end;


procedure TKMLabelScroll.Paint;
var
  newTop: Integer;
  col: Cardinal;
begin
  TKMRenderUI.SetupClipY(AbsTop, AbsTop + Height);
  newTop := EnsureRange(AbsTop + Height - TimeSince(SmoothScrollToTop) div 50, -MINSHORT, MAXSHORT); //Compute delta and shift by it upwards (Credits page)

  if fEnabled then col := FontColor
              else col := $FF888888;

  TKMRenderUI.WriteText(AbsLeft, newTop, Width, fCaption, fFont, fTextAlign, col);
  TKMRenderUI.ReleaseClipY;
end;


{ TKMImage }
constructor TKMImage.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType = rxGui;
                            aPaintLayer: Integer = 0; aImageAnchors: TKMAnchorsSet = [anLeft, anTop]);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);
  fRX := aRX;
  fTexID := aTexID;
  fFlagColor := $FFFF00FF;
  ImageAnchors := aImageAnchors;
  Highlight := False;
  HighlightOnMouseOver := False;
  HighlightCoef := DEFAULT_HIGHLIGHT_COEF;
end;


function TKMImage.GetIsPainted: Boolean;
begin
  Result := inherited and (TexID <> 0);
end;


//DoClick is called by keyboard shortcuts
//It's important that Control must be:
// IsVisible (can't shortcut invisible/unaccessible button)
// Enabled (can't shortcut disabled function, e.g. Halt during fight)
function TKMImage.Click: Boolean;
begin
  if Visible and fEnabled then
  begin
    //Mark self as CtrlOver and CtrlUp, don't mark CtrlDown since MouseUp manually Nils it
    Parent.fMasterControl.CtrlOver := Self;
    Parent.fMasterControl.CtrlUp := Self;
    if Assigned(fOnClick) then fOnClick(Self);
    Result := true; //Click has happened
  end
  else
    Result := False; //No, we couldn't click for Control is unreachable
end;


procedure TKMImage.ImageStretch;
begin
  ImageAnchors := [anLeft, anRight, anTop, anBottom]; //Stretch image to fit
end;


procedure TKMImage.ImageCenter; //Render image from center
begin
  ImageAnchors := [];
end;


{If image area is bigger than image - do center image in it}
procedure TKMImage.Paint;
var
  x, y: Integer;
  col, row: Integer;
  paintLightness: Single;
  drawLeft, drawTop: Integer;
  drawWidth, drawHeight: Integer;
begin
  inherited;
  if fTexID = 0 then Exit; //No picture to draw

  if ClipToBounds then
  begin
    TKMRenderUI.SetupClipX(AbsLeft, AbsLeft + Width);
    TKMRenderUI.SetupClipY(AbsTop,  AbsTop + Height);
  end;

  paintLightness := Lightness + HighlightCoef * (Byte(HighlightOnMouseOver and (csOver in State)) + Byte(Highlight));

  if Tiled then
  begin
    drawWidth := gGFXData[fRX, fTexID].PxWidth;
    drawHeight := gGFXData[fRX, fTexID].PxHeight;
    drawLeft := AbsLeft + fWidth div 2 - drawWidth div 2;
    drawTop := AbsTop + fHeight div 2 - drawHeight div 2;

    col := fWidth div drawWidth + 1;
    row := fHeight div drawHeight + 1;
    for x := -col div 2 to col div 2 do
      for y := -row div 2 to row div 2 do
        TKMRenderUI.WritePicture(drawLeft + x * drawWidth, drawTop + y * drawHeight, drawWidth, drawHeight, ImageAnchors, fRX, fTexID, fEnabled, fFlagColor, paintLightness, PaintingBaseLayer);
 end
  else
    TKMRenderUI.WritePicture(AbsLeft, AbsTop, fWidth, fHeight, ImageAnchors, fRX, fTexID, fEnabled, fFlagColor, paintLightness, PaintingBaseLayer);

  if ClipToBounds then
  begin
    TKMRenderUI.ReleaseClipX;
    TKMRenderUI.ReleaseClipY;
  end;
end;


{ TKMImageStack }
constructor TKMImageStack.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID1, aTexID2: Word; aRX: TRXType = rxGui);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fRX  := aRX;
  fTexID1 := aTexID1;
  fTexID2 := aTexID2;
end;


procedure TKMImageStack.SetCount(aCount, aColumns, aHighlightID: Word);
var
  aspect: Single;
begin
  fCount := aCount;
  fColumns := Math.max(1, aColumns);
  fHighlightID := aHighlightID;

  fDrawWidth  := EnsureRange(Width div fColumns, 8, gGFXData[fRX, fTexID1].PxWidth);
  fDrawHeight := EnsureRange(Height div Ceil(fCount/fColumns), 6, gGFXData[fRX, fTexID1].PxHeight);

  aspect := gGFXData[fRX, fTexID1].PxWidth / gGFXData[fRX, fTexID1].PxHeight;
  if fDrawHeight * aspect <= fDrawWidth then
    fDrawWidth  := Round(fDrawHeight * aspect)
  else
    fDrawHeight := Round(fDrawWidth / aspect);
end;


// If image area is bigger than image - do center image in it
procedure TKMImageStack.Paint;
var
  I: Integer;
  offsetX, offsetY, centerX, centerY: SmallInt; //variable parameters
  texID: Word;
begin
  inherited;
  if fTexID1 = 0 then Exit; //No picture to draw

  offsetX := Width div fColumns;
  offsetY := Height div Ceil(fCount / fColumns);

  centerX := (Width - offsetX * (fColumns-1) - fDrawWidth) div 2;
  centerY := (Height - offsetY * (Ceil(fCount/fColumns) - 1) - fDrawHeight) div 2;

  for I := 0 to fCount - 1 do
  begin
    texID := IfThen(I = fHighlightID, fTexID2, fTexId1);

    TKMRenderUI.WritePicture(AbsLeft + centerX + offsetX * (I mod fColumns),
                            AbsTop + centerY + offsetY * (I div fColumns),
                            fDrawWidth, fDrawHeight, [anLeft, anTop, anRight, anBottom], fRX, texID, fEnabled);
  end;
end;


{ TKMColorSwatch }
constructor TKMColorSwatch.Create(aParent: TKMPanel; aLeft,aTop,aColumnCount,aRowCount,aSize: Integer);
begin
  inherited Create(aParent, aLeft, aTop, 0, 0);

  fBackAlpha    := 0.5;
  fColumnCount  := aColumnCount;
  fRowCount     := aRowCount;
  fCellSize     := aSize;
  fInclRandom   := false;
  fColorIndex   := -1;

  Width  := fColumnCount * fCellSize;
  Height := fRowCount * fCellSize;
end;


procedure TKMColorSwatch.SetColors(const aColors: array of TColor4; aInclRandom: Boolean = False);
begin
  fInclRandom := aInclRandom;
  if fInclRandom then
  begin
    SetLength(Colors, Length(aColors)+SizeOf(TColor4));
    Colors[0] := $00000000; //This one is reserved for random
    Move((@aColors[0])^, (@Colors[1])^, SizeOf(aColors));
  end
  else
  begin
    SetLength(Colors, Length(aColors));
    Move((@aColors[0])^, (@Colors[0])^, SizeOf(aColors));
  end;
end;


procedure TKMColorSwatch.SelectByColor(aColor: TColor4);
var
  I: Integer;
begin
  fColorIndex := -1;
  for I:=0 to Length(Colors)-1 do
    if Colors[I] = aColor then
      fColorIndex := I;
end;


function TKMColorSwatch.GetColor: TColor4;
begin
  if fColorIndex <> -1 then
    Result := Colors[fColorIndex]
  else
    Result := $FF000000; //Black by default
end;


procedure TKMColorSwatch.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  newColor: Integer;
begin
  if Button = mbLeft then
  begin
    newColor := EnsureRange((Y-AbsTop) div fCellSize, 0, fRowCount-1)*fColumnCount +
                EnsureRange((X-AbsLeft) div fCellSize, 0, fColumnCount-1);
    if InRange(newColor, 0, Length(Colors)-1) then
    begin
      fColorIndex := newColor;
      if Assigned(fOnChange) then fOnChange(Self);
    end;
  end;

  inherited;
end;


procedure TKMColorSwatch.Paint;
var
  I, start: Integer;
  selColor: TColor4;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height, 1, fBackAlpha);

  start := 0;
  if fInclRandom then
  begin
    //Render miniature copy of all available colors with '?' on top
    for I := 0 to Length(Colors) - 1 do
      TKMRenderUI.WriteShape(AbsLeft+(I mod fColumnCount)*(fCellSize div fColumnCount)+2, AbsTop+(I div fColumnCount)*(fCellSize div fColumnCount)+2, (fCellSize div fColumnCount), (fCellSize div fColumnCount), Colors[I]);
    TKMRenderUI.WriteText(AbsLeft + fCellSize div 2, AbsTop + fCellSize div 4, 0, '?', fntMetal, taCenter);
    start := 1;
  end;

  for I := start to Length(Colors) - 1 do
    TKMRenderUI.WriteShape(AbsLeft+(I mod fColumnCount)*fCellSize, AbsTop+(I div fColumnCount)*fCellSize, fCellSize, fCellSize, Colors[I]);

  if fColorIndex < 0 then Exit;

  if GetColorBrightness(Colors[fColorIndex]) >= 0.5 then
    selColor := $FF000000
  else
    selColor := $FFFFFFFF;

  //Paint selection
  TKMRenderUI.WriteOutline(AbsLeft+(fColorIndex mod fColumnCount)*fCellSize, AbsTop+(fColorIndex div fColumnCount)*fCellSize, fCellSize, fCellSize, 1, selColor);
end;


{ TKMButton }
constructor TKMButton.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType;
                             aStyle: TKMButtonStyle; aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);
  InitCommon(aStyle);
  fRX   := aRX;
  TexID := aTexID;
end;


{Different version of button, with caption on it instead of image}
constructor TKMButton.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString;
                             aStyle: TKMButtonStyle; aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);
  InitCommon(aStyle);
  Caption := aCaption;
end;


procedure TKMButton.InitCommon(aStyle: TKMButtonStyle);
begin
  TexID             := 0;
  Caption           := '';
  FlagColor         := $FFFF00FF;
  Font              := fntMetal;
  fTextAlign        := taCenter; //Thats default everywhere in KaM
  TextVAlign        := tvaMiddle;//tvaNone;
  fStyle            := aStyle;
  MakesSound        := True;
  ShowImageEnabled  := True;
  AutoHeight        := False;
  AutoTextPadding   := 5;
end;


procedure TKMButton.UpdateHeight;
var
  textY: Integer;
begin
  if fAutoHeight then
  begin
    textY := gRes.Fonts[Font].GetTextSize(Caption).Y;
    if textY + AutoTextPadding > Height then
      Height := textY + AutoTextPadding;
  end;
end;


procedure TKMButton.SetCaption(const aCaption: UnicodeString);
begin
  fCaption := aCaption;
  UpdateHeight;
end;


procedure TKMButton.SetAutoHeight(aValue: Boolean);
begin
  fAutoHeight := aValue;
  UpdateHeight;
end;


//DoClick is called by keyboard shortcuts
//It puts a focus on the button and depresses it if it was DoPress'ed
//It's important that Control must be:
// Visible (can't shortcut invisible/unaccessible button)
// Enabled (can't shortcut disabled function, e.g. Halt during fight)
function TKMButton.Click: Boolean;
begin
  if Visible and fEnabled then
  begin
    //Mark self as CtrlOver and CtrlUp, don't mark CtrlDown since MouseUp manually Nils it
    Parent.fMasterControl.CtrlOver := Self;
    Parent.fMasterControl.CtrlUp := Self;
    if Assigned(fOnClick) then fOnClick(Self);
    Result := true; //Click has happened
  end
  else
    Result := false; //No, we couldn't click for Control is unreachable
end;


procedure TKMButton.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if fEnabled and MakesSound and (csDown in State) then
    gSoundPlayer.Play(sfxnButtonClick);

  inherited;
end;


procedure TKMButton.Paint;
var
  col: TColor4;
  stateSet: TKMButtonStateSet;
  textY, top: Integer;
begin
  inherited;
  stateSet := [];
  if (csOver in State) and fEnabled then
    stateSet := stateSet + [bsOver];
  if (csOver in State) and (csDown in State) then
    stateSet := stateSet + [bsDown];
  if not fEnabled then
    stateSet := stateSet + [bsDisabled];

  TKMRenderUI.Write3DButton(AbsLeft, AbsTop, Width, Height, fRX, TexID, FlagColor, stateSet, fStyle, ShowImageEnabled);

  if TexID <> 0 then Exit;

  //If disabled then text should be faded
  col := IfThen(fEnabled, icWhite, icGray);

  top := AbsTop + Byte(csDown in State) + CapOffsetY;

  textY := gRes.Fonts[Font].GetTextSize(Caption).Y;
  case TextVAlign of
    tvaNone:    Inc(top, (Height div 2) - 7);
    tvaTop:     Inc(top, 2);
    tvaMiddle:  Inc(top, (Height div 2) - (textY div 2) + 2);
    tvaBottom:  Inc(top, Height - textY);
  end;
  TKMRenderUI.WriteText(AbsLeft + Byte(csDown in State) + CapOffsetX, top,
                        Width, Caption, Font, fTextAlign, col);
end;


{TKMButtonFlatCommon}
constructor TKMButtonFlatCommon.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight, aTexID: Integer; aRX: TRXType = rxGui);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  RX        := aRX;
  TexID     := aTexID;
  FlagColor := $FFFF00FF;
  CapColor  := $FFFFFFFF;
  Font      := fntGame;
  Clickable := True;
end;


procedure TKMButtonFlatCommon.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if not Clickable then Exit;
  if fEnabled and (csDown in State) then
    gSoundPlayer.Play(sfxClick);

  inherited;
end;


procedure TKMButtonFlatCommon.Paint;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  if (csOver in State) and fEnabled and not HideHighlight then
    TKMRenderUI.WriteShape(AbsLeft+1, AbsTop+1, Width-2, Height-2, $40FFFFFF);
end;


//Simple version of button, with a caption and image
{TKMButtonFlat}
procedure TKMButtonFlat.Paint;
var
  textCol: TColor4;
begin
  inherited;

  if TexID <> 0 then
    TKMRenderUI.WritePicture(AbsLeft + TexOffsetX,
                             AbsTop + TexOffsetY - 6 * Byte(Caption <> ''),
                             Width, Height, [], RX, TexID, fEnabled or fEnabledVisually, FlagColor);

  textCol := IfThen(fEnabled or fEnabledVisually, CapColor, icGray);
  TKMRenderUI.WriteText(AbsLeft + CapOffsetX, AbsTop + (Height div 2) + 4 + CapOffsetY, Width, Caption, Font, taCenter, textCol);

  if Down then
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, 1, $FFFFFFFF);
  {if not fEnabled then
    TKMRenderUI.WriteShape(Left, Top, Width, Height, $80000000);}
end;


{ TKMFlatButtonShape }
constructor TKMFlatButtonShape.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aShapeColor: TColor4);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fCaption    := aCaption;
  ShapeColor  := aShapeColor;
  fFont       := aFont;
  fFontHeight := gRes.Fonts[fFont].BaseHeight + 2;
  FontColor   := icWhite;
end;


procedure TKMFlatButtonShape.Paint;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  //Shape within bevel
  TKMRenderUI.WriteShape(AbsLeft + 1, AbsTop + 1, Width - 2, Width - 2, ShapeColor);

  TKMRenderUI.WriteText(AbsLeft, AbsTop + (Height - fFontHeight) div 2,
                      Width, fCaption, fFont, taCenter, FontColor);

  if (csOver in State) and fEnabled then
    TKMRenderUI.WriteShape(AbsLeft + 1, AbsTop + 1, Width - 2, Height - 2, $40FFFFFF);

  if (csDown in State) or Down then
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, 1, icWhite);
end;


{ TKMSelectableEdit }
constructor TKMSelectableEdit.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  CursorPos := 0;

  //Text input fields are focusable by concept
  Focusable := True;
  ReadOnly := False;
  BlockInput := False;
  fSelectable := aSelectable;

  // Subscribe to get other controls mouse down events
  // Descendants of TKMSelectableEdit could add more event handlers
  aParent.fMasterControl.AddMouseDownCtrlSub(SelEditCtrlMouseDown);
end;


procedure TKMSelectableEdit.DeleteSelectedText;
begin
  Delete(fText, fSelectionStart+1, fSelectionEnd-fSelectionStart);

  if CursorPos = fSelectionEnd then
    CursorPos := CursorPos - (fSelectionEnd-fSelectionStart);

  ResetSelection;
end;


function TKMSelectableEdit.GetCursorPosAt(X: Integer): Integer;
var
  rText: UnicodeString;
begin
  rText := Copy(fText, fLeftIndex+1, Length(fText) - fLeftIndex);
  if gRes.Fonts[fFont].GetTextSize(rText, DoShowMarkup, DrawEolSymbol).X < X-SelfAbsLeft-4 then
    Result := Length(rText) + fLeftIndex
  else
    Result := gRes.Fonts[fFont].CharsThatFit(rText, X-SelfAbsLeft-4, DoShowMarkup, DrawEolSymbol) + fLeftIndex;
end;


function TKMSelectableEdit.GetSelectedText: UnicodeString;
begin
  Result := '';
  if HasSelection then
    Result := Copy(fText, fSelectionStart+1, fSelectionEnd - fSelectionStart);
end;


function TKMSelectableEdit.HasSelection: Boolean;
begin
  Result := (fSelectionStart <> -1) and (fSelectionEnd <> -1) and (fSelectionStart <> fSelectionEnd);
end;


procedure TKMSelectableEdit.ResetSelection;
begin
  fSelectionStart := -1;
  fSelectionEnd := -1;
  fSelectionInitialPos := -1;
end;


procedure TKMSelectableEdit.SetSelectionEnd(aValue: Integer);
begin
  if fSelectable then
    fSelectionEnd := EnsureRange(aValue, 0, Length(fText));
end;


procedure TKMSelectableEdit.SetSelectionStart(aValue: Integer);
begin
  if fSelectable then
    fSelectionStart := EnsureRange(aValue, 0, Length(fText));
end;


//Set selections with pair of value, using he fact, that fSelectionStart <= fSelectionEnd
procedure TKMSelectableEdit.SetSelections(aValue1, aValue2: Integer);
begin
  SelectionStart := Min(aValue1, aValue2);
  SelectionEnd := Max(aValue1, aValue2);
end;


procedure TKMSelectableEdit.ValidateText(aTriggerOnChange: Boolean = True);
begin
  if aTriggerOnChange then
    Changed;
end;


procedure TKMSelectableEdit.Changed;
begin
  // OnChange should be called here, since we changed the input and don't want to wait until KeyUp event
  if Assigned(OnChange) then
    OnChange(Self);
end;


procedure TKMSelectableEdit.SetCursorPos(aPos: Integer);
var
  rText: UnicodeString;
begin
  fCursorPos := EnsureRange(aPos, 0, Length(fText));
  if fCursorPos < fLeftIndex then
    fLeftIndex := fCursorPos
  else
  begin
    //Remove characters to the left of fLeftIndex
    rText := Copy(fText, fLeftIndex+1, Length(fText));
    while fCursorPos-fLeftIndex > gRes.Fonts[fFont].CharsThatFit(rText, Width-8, False, DrawEolSymbol) do
    begin
      Inc(fLeftIndex);
      //Remove characters to the left of fLeftIndex
      rText := Copy(fText, fLeftIndex+1, Length(fText));
    end;
  end;
end;


//Update selection start/end due to change cursor position
procedure TKMSelectableEdit.UpdateSelection(aOldCursorPos: Integer; aIsSelecting: Boolean);
begin
  if aIsSelecting then
  begin
    if HasSelection then
    begin
      if aOldCursorPos = SelectionStart then
        SetSelections(CursorPos, SelectionEnd)
      else
      if aOldCursorPos = SelectionEnd then
        SetSelections(SelectionStart, CursorPos);
    end else
      SetSelections(aOldCursorPos, CursorPos);
  end
  else
    ResetSelection;
end;


function TKMSelectableEdit.KeyDown(Key: Word; Shift: TShiftState): Boolean;

  // Update cursor pos considering Ctrl Key to go to the next / prev word in the text
  procedure UpdateCursorPos(aCursorDir: TKMCursorDir);
  begin
    if ssCtrl in Shift then
    begin
      case aCursorDir of
        cdNone:     ;
        cdForward:  CursorPos := GetNextWordPos(fText, CursorPos);
        cdBack:     CursorPos := GetPrevWordPos(fText, CursorPos);
      end;
    end
    else
      CursorPos := CursorPos + ShortInt(aCursorDir);
  end;

var
  oldCursorPos: Integer;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyDown(Key, Shift) or ReadOnly then Exit;

  //Allow some keys while blocking input
  if BlockInput
    and not ((Key in [VK_LEFT, VK_RIGHT, VK_HOME, VK_END])
      or ((ssCtrl in Shift) and (Key in [VK_LEFT, VK_RIGHT, Ord('A'), Ord('C')]))) then Exit;

  oldCursorPos := CursorPos;

  //Clipboard operations
  if (Shift = [ssCtrl]) and (Key <> VK_CONTROL) then
    case Key of
      Ord('A'): begin
                  SelectionStart := 0;
                  SelectionEnd := Length(fText);
                end;
      Ord('C'): if HasSelection then
                  Clipboard.AsText := GetSelectedText;
      Ord('X'): if HasSelection then
                begin
                  Clipboard.AsText := GetSelectedText;
                  DeleteSelectedText;
                  ValidateText;
                end;
      Ord('V'): begin
                  if HasSelection then
                  begin
                    Delete(fText, fSelectionStart + 1, fSelectionEnd-fSelectionStart);
                    Insert(Clipboard.AsText, fText, fSelectionStart + 1);
                    ValidateText;
                    if CursorPos = fSelectionStart then
                      CursorPos := CursorPos + Length(Clipboard.AsText)
                    else if CursorPos = fSelectionEnd then
                      CursorPos := CursorPos + Length(Clipboard.AsText) - (fSelectionEnd-fSelectionStart);
                    ResetSelection;
                  end else begin
                    Insert(Clipboard.AsText, fText, CursorPos + 1);
                    ValidateText;
                    CursorPos := CursorPos + Length(Clipboard.AsText);
                  end;
                end;
    end;

  case Key of
    VK_BACK:    if HasSelection then
                begin
                  DeleteSelectedText;
                  ValidateText;
                end
                else
                begin
                  Delete(fText, CursorPos, 1);
                  CursorPos := CursorPos - 1;
                  ValidateText;
                end;
    VK_DELETE:  if HasSelection then
                begin
                  DeleteSelectedText;
                  ValidateText;
                end
                else
                begin
                  Delete(fText, CursorPos + 1, 1);
                  ValidateText;
                end;
  end;

  case Key of
    VK_LEFT,
    VK_RIGHT: begin
                UpdateCursorPos(GetCursorDir(Key));
                UpdateSelection(oldCursorPos, IsSelecting(Key, Shift));
              end;
    VK_HOME:  begin
                CursorPos := 0;
                UpdateSelection(oldCursorPos, IsSelecting(Key, Shift));
              end;
    VK_END:   begin
                CursorPos := Length(fText);
                UpdateSelection(oldCursorPos, IsSelecting(Key, Shift));
              end;
  end;
end;


procedure TKMSelectableEdit.KeyPress(Key: Char);
begin
  inherited;

  if ReadOnly or BlockInput then Exit;

  if HasSelection and IsCharValid(Key) then
    DeleteSelectedText
  else
  if Length(fText) >= GetMaxLength then Exit;

  Insert(Key, fText, CursorPos + 1);
  CursorPos := CursorPos + 1; //Before ValidateText so it moves the cursor back if the new char was invalid
  ValidateText; //Validate text at the end of all changes (delete selected and insert)
end;


function TKMSelectableEdit.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyUp(Key, Shift) or ReadOnly then Exit;
end;


procedure TKMSelectableEdit.MouseDown(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  oldCursorPos: Integer;
begin
  if ReadOnly then Exit;
  inherited;
  // Update Focus now, because we need to focus on MouseDown, not on MouseUp as by default for all controls
  MasterParent.fMasterControl.UpdateFocus(Self);

  oldCursorPos := CursorPos;
  CursorPos := GetCursorPosAt(X);

  if Focusable then
  begin
    //Try select on Shift + LMB click
    UpdateSelection(oldCursorPos, (oldCursorPos <> -1) and (Shift = [ssLeft, ssShift]));
    fSelectionInitialPos := CursorPos;
  end;
end;


procedure TKMSelectableEdit.MouseMove(X, Y: Integer; Shift: TShiftState);
var
  curCursorPos, oldCursorPos: Integer;
begin
  if ReadOnly then Exit;
  inherited;
  if (ssLeft in Shift) and (fSelectionInitialPos <> -1) then
  begin
    curCursorPos := GetCursorPosAt(X);
    // To rotate line to left while selecting
    if (X-SelfAbsLeft-4 < 0) and (fLeftIndex > 0) then
      curCursorPos := curCursorPos - 1;

    oldCursorPos := CursorPos;
    CursorPos := CurCursorPos;
    UpdateSelection(oldCursorPos, True);
  end;
end;


procedure TKMSelectableEdit.MouseUp(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if ReadOnly then Exit;
  inherited;
  fSelectionInitialPos := -1;
end;


procedure TKMSelectableEdit.PaintSelection;
var
  beforeSelectionText, selectionText: UnicodeString;
  beforeSelectionW, selectionW: Integer;
begin
  if HasSelection then
  begin
    beforeSelectionText := Copy(fText, fLeftIndex+1, max(fSelectionStart, fLeftIndex) - fLeftIndex);
    selectionText := Copy(fText, max(fSelectionStart, fLeftIndex)+1, fSelectionEnd - max(fSelectionStart, fLeftIndex));

    beforeSelectionW := gRes.Fonts[fFont].GetTextSize(beforeSelectionText, DoShowMarkup, DrawEolSymbol).X;
    selectionW := gRes.Fonts[fFont].GetTextSize(selectionText, DoShowMarkup, DrawEolSymbol).X;

    TKMRenderUI.WriteShape(SelfAbsLeft+4+beforeSelectionW, AbsTop+3, min(selectionW, Width-8), Height-6, clTextSelection);
  end;
end;


function TKMSelectableEdit.DrawEolSymbol: Boolean;
begin
  Result := False; //EOL is not showing by default
end;


function TKMSelectableEdit.DoShowMarkup: Boolean;
begin
  Result := False; //MarkUp is not showing by default
end;


procedure TKMSelectableEdit.SelEditCtrlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if (Sender <> Self) then
    ResetSelection;
end;


//function TKMSelectableEdit.GetControlMouseDownProc: TKMMouseUpDownEvent;
//begin
//  Result := ControlMouseDown;
//end;


procedure TKMSelectableEdit.FocusChanged(aFocused: Boolean);
begin
  inherited;
  if not aFocused then
    ResetSelection;
end;


{ TKMEdit }
constructor TKMEdit.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aSelectable);
  fAllowedChars := acText; //Set to the widest by default
  MaxLen := 256; //Default max length to prevent chat spam
end;


function TKMEdit.GetMaxLength: Word;
begin
  Result := MaxLen;
end;


function TKMEdit.GetRText: UnicodeString;
begin
  if Masked then
    Result := StringOfChar('*', Length(fText))
  else
    Result := fText;
  Result := Copy(Result, fLeftIndex+1, Length(Result));
end;


function TKMEdit.DrawEolSymbol: Boolean;
begin
  Result := AllowedChars = acAll;
end;


function TKMEdit.DoShowMarkup: Boolean;
begin
  Result := ShowColors;
end;


function TKMEdit.HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): Boolean;
begin
  //When control is read-only we don't want to recieve Focus event
  Result := inherited HitTest(X,Y) and not ReadOnly;
end;


procedure TKMEdit.SetText(const aText: UnicodeString);
begin
  UpdateText(aText);
  //Setting the text should place cursor to the end
  fLeftIndex := 0;
  SetCursorPos(Length(Text));
end;


procedure TKMEdit.UpdateText(const aText: UnicodeString; aTriggerOnChange: Boolean = True);
begin
  fText := aText;
  ValidateText(aTriggerOnChange); //Validate first since it could change fText
  CursorPos := Math.Min(CursorPos, Length(fText));
end;


procedure TKMEdit.SetTextSilently(const aText: UnicodeString);
begin
  UpdateText(aText, False);
end;


function TKMEdit.IsCharValid(aChar: WideChar): Boolean;
begin
  Result := IsCharAllowed(aChar, fAllowedChars);
end;


//Validates fText basing on predefined sets of allowed or disallowed chars
//It iterates from end to start of a string - deletes chars and moves cursor appropriately
procedure TKMEdit.ValidateText(aTriggerOnChange: Boolean = True);
var
  I: Integer;
begin
  //Parse whole text incase user placed it from clipboard
  //Validate contents
  for I := Length(fText) downto 1 do
    if not IsCharValid(fText[I]) then
    begin
      Delete(fText, I, 1);
      if CursorPos >= I then //Keep cursor in place
        CursorPos := CursorPos - 1;
    end;

  //Validate length
  if Length(fText) > MaxLen then
    fText := Copy(fText, 0, MaxLen);

  inherited ValidateText(aTriggerOnChange); //Could trigger OnChange event
end;


//Key events which have no effect should not be handled (allows scrolling while chat window open with no text entered)
function TKMEdit.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;

  //Don't include backspace/delete because edits should always handle those. Otherwise when you
  //press backspace repeatedly to remove all characters it will apply other shortcuts like
  //resetting the zoom if you press it once too many times.
  case Key of
    VK_UP,
    VK_DOWN,
    VK_LEFT,
    VK_RIGHT,
    VK_HOME,
    VK_END: Result := (fText <> ''); //These keys have no effect when text is blank
  end;

  //We want these keys to be ignored by TKMEdit
  if Key in [VK_F1..VK_F12, VK_ESCAPE, VK_RETURN, VK_TAB] then Result := False;

  //Ctrl can be used as an escape character, e.g. CTRL+B places beacon while chat is open
  if ssCtrl in Shift then Result := (Key in [VK_LEFT, VK_RIGHT, Ord('A'), Ord('C'), Ord('X'), Ord('V')]);

  // If key is ignored, then check if can still handle it (check via OnIsKeyEventHandled)
  if not Result and Assigned(OnIsKeyEventHandled) then
    Result := OnIsKeyEventHandled(Self, Key);
end;


procedure TKMEdit.Paint;
var
  col: TColor4;
  rText: UnicodeString;
  offX: Integer;
begin
  inherited;

  if DrawOutline then
  begin
    TKMRenderUI.WriteShape(AbsLeft-1, AbsTop-1, Width+2, Height+2, $00000000, OutlineColor);
    TKMRenderUI.WriteShape(AbsLeft-2, AbsTop-2, Width+4, Height+4, $00000000, OutlineColor);
  end;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  if not fEnabled then
    col := icGray2
  else if BlockInput then
    col := icLightGray
  else
    col := icWhite;

  if Masked then
    rText := StringOfChar('*', Length(fText))
  else
    rText := fText;
  rText := Copy(fText, fLeftIndex+1, Length(fText)); //Remove characters to the left of fLeftIndex

  PaintSelection;

  //Characters that do not fit are trimmed
  TKMRenderUI.WriteText(AbsLeft+4, AbsTop+3, Width-8, rText, fFont, taLeft, col, not ShowColors, True, DrawEolSymbol);

  //Render text cursor
  if (csFocus in State) and ((TimeGet div 500) mod 2 = 0) then
  begin
    SetLength(rText, CursorPos - fLeftIndex);
    offX := AbsLeft + 2 + gRes.Fonts[fFont].GetTextSize(rText, True, DrawEolSymbol).X;
    TKMRenderUI.WriteShape(offX, AbsTop+2, 3, Height-4, col, $FF000000);
  end;
end;


{ TKMFilenameEdit }
constructor TKMFilenameEdit.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);
const
  MAX_SAVENAME_LENGTH = 50;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aSelectable);

  fAllowedChars := acFileName; // Set to the widest by default
  MaxLen := MAX_SAVENAME_LENGTH;
end;


function TKMFilenameEdit.GetIsValid: Boolean;
const
  // Windows has the following reserved folder names, according to:
  // https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
  WIN_RESERVED_FILENAMES: array [0..21] of string = (
    'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6',
    'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7',
    'LPT8', 'LPT9');
var
  S, txt: string;
begin
  txt := Trim(fText);
  Result := txt <> '';
  if not Result then Exit;

  for S in WIN_RESERVED_FILENAMES do
    if S = txt.ToUpper then
      Exit(False);
end;


{ TKMCheckBox }
constructor TKMCheckBox.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString;
                               aFont: TKMFont; aHasSemiState: Boolean = False);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont     := aFont;
  fCaption  := aCaption;
  fHasSemiState := aHasSemiState;
  LineWidth := 1;
  LineColor := clChkboxOutline;
end;


procedure TKMCheckBox.SetChecked(aChecked: Boolean);
begin
  if aChecked then
    fState := cbsChecked
  else
    fState := cbsUnchecked;
end;


function TKMCheckBox.GetCheckedBool: Boolean;
begin
  Result := fState = cbsChecked;
end;


function TKMCheckBox.IsSemiChecked: Boolean;
begin
  Result := fState = cbsSemiChecked;
end;


procedure TKMCheckBox.Check;
begin
  fState := cbsChecked;
end;


procedure TKMCheckBox.SemiCheck;
begin
  fState := cbsSemiChecked;
end;


procedure TKMCheckBox.Uncheck;
begin
  fState := cbsUnchecked;
end;


procedure TKMCheckBox.SwitchCheck(aForward: Boolean = True);
begin
  if fHasSemiState then
    fState := TKMCheckBoxState((Byte(fState) + 3 + 2*Byte(aForward) - 1) mod 3)
  else
  begin
    if Checked then
      Uncheck
    else
      Check;
  end;
end;


procedure TKMCheckBox.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if (csDown in State) and (Button = mbLeft) then
    case fState of
      cbsSemiChecked,
      cbsUnchecked:   Check; //Let's assume we prefer check for now
      cbsChecked:     Uncheck;
    end;
  inherited; //There are OnMouseUp and OnClick events there
end;


//We can replace it with something better later on. For now [x] fits just fine
//Might need additional graphics to be added to gui.rx
//Some kind of box with an outline, darkened background and shadow maybe, similar to other controls.
procedure TKMCheckBox.Paint;
var
  col, semiCol: TColor4;
  checkSize: Integer;
begin
  inherited;

  if fEnabled then
  begin
    col := icWhite;
    semiCol := $FFCCCCCC;
  end
  else
  begin
    col := icGray2;
    semiCol := $FF888888;
  end;

  checkSize := gRes.Fonts[fFont].GetTextSize('x').Y + 1;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, checkSize - 4, checkSize-4, 1, {0.35 - }Byte(not IsSemiChecked)*0.35);

  if DrawOutline then
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, checkSize - 4, checkSize - 4, LineWidth, LineColor);

  case fState of
    cbsChecked:     TKMRenderUI.WriteText(AbsLeft + (checkSize-4) div 2, AbsTop - 1, 0, 'x', fFont, taCenter, col);
    cbsSemiChecked: TKMRenderUI.WriteText(AbsLeft + (checkSize-4) div 2, AbsTop - 1, 0, 'x', fFont, taCenter, semiCol);
    cbsUnchecked: ; //Do not draw anything
  end;


  TKMRenderUI.WriteText(AbsLeft + checkSize, AbsTop, Width - checkSize, fCaption, fFont, taLeft, col);
end;


{ TKMRadioGroup }
constructor TKMRadioGroup.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  fItemIndex := -1;
  LineWidth := 1;
  LineColor := clChkboxOutline;
  AllowUncheck := False;
end;


procedure TKMRadioGroup.Add(const aText: String; aEnabled: Boolean);
begin
  Add(aText, '', aEnabled);
end;


procedure TKMRadioGroup.Add(const aText: String; aEnabled, aVisible: Boolean);
begin
  Add(aText, '', aEnabled, aVisible);
end;


procedure TKMRadioGroup.Add(const aText, aHint: String; aEnabled: Boolean = True; aVisible: Boolean = True);
begin
  if fCount >= Length(fItems) then
    SetLength(fItems, fCount + 8);

  fItems[fCount].Text := aText;
  fItems[fCount].Hint := aHint;
  fItems[fCount].Enabled := aEnabled;
  fItems[fCount].Visible := aVisible;

  Inc(fCount);
end;


procedure TKMRadioGroup.Clear;
begin
  fCount := 0;
end;


procedure TKMRadioGroup.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  changed: Boolean;
begin
  if (csDown in State) and (Button = mbLeft) then
  begin
    UpdateMouseOverPositions(X,Y);
    if (fMouseOverItem <> -1) and fItems[fMouseOverItem].Enabled then
    begin
      changed := False;
      if (fMouseOverItem = fItemIndex) then
      begin
        if AllowUncheck then
        begin
          fItemIndex := -1; //Uncheck
          changed := True;
        end;
      end else begin
        fItemIndex := fMouseOverItem;
        changed := True;
      end;

      if changed and Assigned(fOnChange) then
      begin
        fOnChange(Self);
        Exit; //Don't generate OnClick after OnChanged event (esp. when reloading Game on local change)
      end;
    end;
  end;

  inherited; //There are OnMouseUp and OnClick events there
end;


procedure TKMRadioGroup.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;
  UpdateMouseOverPositions(X,Y);
end;


procedure TKMRadioGroup.UpdateMouseOverPositions(X,Y: Integer);
var
  mouseOverRow, itemIndex: Integer;
begin
  fMouseOverItem := -1;

  if InRange(Y, AbsTop, AbsTop + Height) and (LineHeight > 0) then
  begin
    mouseOverRow := EnsureRange((Y - AbsTop) div Round(LineHeight), 0, VisibleCount - 1);
    itemIndex := GetItemIndexByRow(mouseOverRow);
    if (itemIndex <> -1) and InRange(X, AbsLeft, AbsLeft + LineHeight + gRes.Fonts[fFont].GetTextSize(fItems[itemIndex].Text).X) then
      fMouseOverItem := itemIndex;
  end;
end;


function TKMRadioGroup.GetItem(aIndex: Integer): TKMRadioGroupItem;
begin
  Assert(aIndex < fCount, 'Can''t get radio group item for index ' + IntToStr(aIndex));
  Result := fItems[aIndex];
end;


function TKMRadioGroup.GetItemIndexByRow(aRowIndex: Integer): Integer;
var
  I, K: Integer;
begin
  Assert(aRowIndex < VisibleCount, 'GetItemByRow: aRowIndex >= VisibleCount');
  K := 0;
  Result := -1;
  for I := 0 to fCount - 1 do
  begin
    if not fItems[I].Visible then Continue;
    if aRowIndex = K then
    begin
      Result := I;
      Exit;
    end;
    Inc(K);
  end;
end;


function TKMRadioGroup.GetVisibleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to fCount - 1 do
    if fItems[I].Visible then
      Inc(Result);
end;


function TKMRadioGroup.GetLineHeight: Single;
begin
  Result := IfThen(VisibleCount > 0, fHeight / VisibleCount, fHeight);
end;


function TKMRadioGroup.GetIsSelected: Boolean;
begin
  Result := fItemIndex <> -1;
end;


procedure TKMRadioGroup.SetItemEnabled(aIndex: Integer; aEnabled: Boolean; aUncheckDisabled: Boolean = True);
begin
  Assert(aIndex < fCount, 'Can''t SetItemEnabled for index ' + IntToStr(aIndex));
  fItems[aIndex].Enabled := aEnabled;

  // Reset item index, if this item was selected
  if aUncheckDisabled and not aEnabled and (fItemIndex = aIndex) then
    fItemIndex := -1;
end;


procedure TKMRadioGroup.SetItemVisible(aIndex: Integer; aEnabled: Boolean);
begin
  Assert(aIndex < fCount, 'Can''t SetItemVisible for index ' + IntToStr(aIndex));
  fItems[aIndex].Visible := aEnabled;
end;


procedure TKMRadioGroup.CheckFirstCheckable;
var
  I: Integer;
begin
  if fItemIndex <> -1 then Exit;

  for I := 0 to fCount - 1 do
    if fItems[I].Enabled and fItems[I].Visible then
    begin
      fItemIndex := I;
      Exit;
    end;
end;


function TKMRadioGroup.GetHint: UnicodeString;
begin
  Result := inherited GetHint;
  if Result = '' then
  begin
    if fMouseOverItem <> -1 then
      Result := fItems[fMouseOverItem].Hint;
  end;
end;


//We can replace it with something better later on. For now [x] fits just fine
//Might need additional graphics to be added to gui.rx
//Some kind of box with an outline, darkened background and shadow maybe, similar to other controls.
procedure TKMRadioGroup.Paint;
const
  FONT_COL: array [Boolean] of TColor4 = ($FF888888, $FFFFFFFF);
var
  CheckSize: Integer;
  I, VisibleI: Integer;
begin
  inherited;
  if (Count = 0) or (VisibleCount = 0) then Exit; //Avoid dividing by zero

  CheckSize := gRes.Fonts[fFont].GetTextSize('x').Y + 1;

  VisibleI := 0;
  for I := 0 to Count - 1 do
  begin
    if not fItems[I].Visible then
      Continue;

    TKMRenderUI.WriteBevel(AbsLeft, AbsTop + Round(VisibleI * LineHeight), CheckSize-4, CheckSize-4, 1, 0.3);
    if DrawChkboxOutline then
      TKMRenderUI.WriteOutline(AbsLeft, AbsTop + Round(VisibleI * LineHeight), CheckSize-4, CheckSize-4, LineWidth, LineColor);

    if fItemIndex = I then
      TKMRenderUI.WriteText(AbsLeft + (CheckSize - 4) div 2, AbsTop + Round(VisibleI * LineHeight) - 1, 0,
                            'x', fFont, taCenter, FONT_COL[fEnabled and fItems[I].Enabled]);

    // Caption
    TKMRenderUI.WriteText(AbsLeft + CheckSize, AbsTop + Round(VisibleI * LineHeight), Width - Round(LineHeight),
                          fItems[I].Text, fFont, taLeft, FONT_COL[fEnabled and fItems[I].Enabled]);
    Inc(VisibleI);
  end;
end;


{ TKMProgressBar }
constructor TKMProgressBarAbstract.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fntMini;
                                          aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);
  fFont := aFont;
  FontColor := $FFFFFFFF;
  fTextAlign := taCenter;
end;


procedure TKMProgressBarAbstract.SetCaptions(const aCaptionLeft, aCaption, aCaptionRight: UnicodeString);
begin
  CaptionLeft := aCaptionLeft;
  Caption := aCaption;
  CaptionRight := aCaptionRight;
end;


procedure TKMProgressBarAbstract.Paint;
var
  captionSize: TKMPoint;
begin
  inherited;

  PaintBar;

  //Now draw text over the bar, if it is required
  if Caption <> '' then
  begin
    //Shadow
    TKMRenderUI.WriteText(AbsLeft + 2, (AbsTop + Height div 2)+TextYOffset-4,
                          Width-4, Caption, fFont, fTextAlign, $FF000000);
    //Text
    TKMRenderUI.WriteText(AbsLeft + 1, (AbsTop + Height div 2)+TextYOffset-5,
                          Width-4, Caption, fFont, fTextAlign, FontColor);
  end;

  if (CaptionLeft <> '') or (CaptionRight <> '') then
    captionSize := gRes.Fonts[fFont].GetTextSize(Caption);

  if CaptionLeft <> '' then
  begin
    //Shadow
    TKMRenderUI.WriteText(AbsLeft + 2, (AbsTop + Height div 2)+TextYOffset-4,
                         (Width-4 - captionSize.X) div 2, CaptionLeft, fFont, taRight, $FF000000);
    //Text
    TKMRenderUI.WriteText(AbsLeft + 1, (AbsTop + Height div 2)+TextYOffset-5,
                         (Width-4 - captionSize.X) div 2, CaptionLeft, fFont, taRight, FontColor);
  end;

  if CaptionRight <> '' then
  begin
    //Shadow
    TKMRenderUI.WriteText(AbsLeft + 2 + ((Width-4 + captionSize.X) div 2), (AbsTop + Height div 2)+TextYOffset-4,
                         (Width-4 - captionSize.X) div 2, CaptionRight, fFont, taLeft, $FF000000);
    //Text
    TKMRenderUI.WriteText(AbsLeft + 1 + ((Width-4 + captionSize.X) div 2), (AbsTop + Height div 2)+TextYOffset-5,
                         (Width-4 - captionSize.X) div 2, CaptionRight, fFont, taLeft, FontColor);
  end;
end;


{ TKMPercentBar }
constructor TKMPercentBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fntMini;
                                 aPaintLayer: Integer = 0);
begin
  inherited;

  fMainColor := icBarColorGreen;
  fAddColor := icBarColorBlue;
end;

procedure TKMPercentBar.SetPosition(aValue: Single);
begin
  fPosition := EnsureRange(aValue, 0, 1);
end;


procedure TKMPercentBar.SetSeam(aValue: Single);
begin
  fSeam := EnsureRange(aValue, 0, 1);
end;


procedure TKMPercentBar.PaintBar;
begin
  TKMRenderUI.WritePercentBar(AbsLeft, AbsTop, Width, Height, fPosition, fSeam, fMainColor, fAddColor);
end;


{ TKMReplayBar }
constructor TKMReplayBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fntMini);
begin
  Create(aParent, aLeft, aTop, aWidth, aHeight, 0, MaxInt, MaxInt, aFont);
end;


constructor TKMReplayBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight, aPosition, aPeacetime, aMaxValue: Integer;
                                aFont: TKMFont = fntMini);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont);

  SetParameters(aPosition, aPeacetime, aMaxValue);
  fMarksPattern := $CF3; //Looks good for 25px height bar

  fHighlightMark := -1;

  fMarks := TList<Integer>.Create;

  // Subscribe to get other controls mouse move events
  aParent.fMasterControl.AddMouseMoveCtrlSub(ControlMouseMove);
end;


destructor TKMReplayBar.Destroy;
begin
  FreeAndNil(fMarks);
end;


procedure TKMReplayBar.SetParameters(aPosition, aPeacetime, aMaxValue: Integer);
begin
  //Apply setters
  MaxValue := aMaxValue; //Should be first, since we restrict Position and PT with MaxValue
  SetPosition(aPosition);
  SetPeacetime(aPeacetime);
end;


procedure TKMReplayBar.AddMark(aMark: Integer);
begin
  if Self = nil then Exit;

  Assert(fMarks <> nil, 'Marks is not initilized');

  fMarks.Add(aMark);
  fIsDirty := True;
end;


procedure TKMReplayBar.SetPosition(aValue: Integer);
begin
  fPosition := EnsureRange(aValue, 0, fMaxValue);
//  Caption := IntToStr(fPosition);
end;


procedure TKMReplayBar.SetPeacetime(aValue: Integer);
begin
  fPeacetime := EnsureRange(aValue, 0, MaxInt);
end;


procedure TKMReplayBar.SetMaxValue(aValue: Integer);
begin
  fMaxValue := EnsureRange(aValue, 1, MaxInt);
end;


procedure TKMReplayBar.MouseMove(X,Y: Integer; Shift: TShiftState);
const
  MAX_DIST_PERCENT = 0.02;
var
  pos, bestDist, dist: Integer;
  mark, bestMark: Integer;
begin
  inherited;
  pos := Round((X - AbsLeft) / Width * MaxValue);

  bestDist := MaxInt;
  bestMark := -1;

  TrySortMarks;
  for mark in fMarks do
  begin
    dist := Abs(pos - mark);
    if dist < MAX_DIST_PERCENT*fMaxValue then
    begin
      if dist < bestDist then
      begin
        bestDist := dist;
        bestMark := mark;
      end else
        Break; //List is sorted, we have found what we need
    end;
  end;

  fHighlightMark := bestMark;

  if fHighlightMark <> -1 then
  begin
    Hint := Format(gResTexts[fHintResText], [TickToTimeStr(fHighlightMark)]);
//    Caption := IntToStr(fPosition) + ' (' + IntToStr(fHighlightMark) + ')';
  end
  else
  begin
    Hint := '';
//    Caption := IntToStr(fPosition);
  end;
end;


procedure TKMReplayBar.MouseUp(X: Integer; Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  if (fHighlightMark <> -1) and Assigned(fOnMarkClick) then
    fOnMarkClick(fHighlightMark);
end;


procedure TKMReplayBar.TrySortMarks;
begin
  if fIsDirty then
  begin
    fIsDirty := False;
    fMarks.Sort;
  end;
end;


procedure TKMReplayBar.PaintBar;
begin
  inherited;
  TKMRenderUI.WriteReplayBar(AbsLeft, AbsTop, Width, Height, fPosition, fPeacetime, fMaxValue, fMarks, MarksPattern, fHighlightMark);
end;


procedure TKMReplayBar.Clear;
begin
  fMarks.Clear;
end;


procedure TKMReplayBar.ControlMouseMove(Sender: TObject; X, Y: Integer; Shift: TShiftState);
begin
  inherited;
  if not InRange(X, AbsLeft, AbsRight)
    or not InRange(Y, AbsTop, AbsBottom) then
    fHighlightMark := -1;
end;


{ TKMWaresRow }
constructor TKMWaresRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer);
begin
  Create(aParent, aLeft, aTop, aWidth, False);
end;


constructor TKMWaresRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aClickable: Boolean);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, WARE_ROW_HEIGHT, 0);
  Clickable := aClickable;
  HideHighlight := not aClickable;
end;


procedure TKMWaresRow.Paint;
var
  I: Integer;
begin
  inherited;
  TKMRenderUI.WriteText(AbsLeft + 4, AbsTop + 3, Width-8, Caption, fntGame, taLeft, $FFE0E0E0);
  //Render in reverse order so the rightmost resource is on top (otherwise lighting looks wrong)
  if WareCntAsNumber then
  begin
    TKMRenderUI.WriteText(AbsLeft + Width - 18 - 70 + 24, AbsTop + 3, 22, IntToStr(WareCount), fntGame, taRight, $FFE0E0E0);
    TKMRenderUI.WritePicture(AbsLeft + Width - 18, AbsTop + 3, 14, 14, [], RX, TexID);
  end else
    for I := WareCount - 1 downto 0 do
      TKMRenderUI.WritePicture(AbsLeft + Width - 18 - I * 14, AbsTop + 3, 14, 14, [], RX, TexID);
end;


{ TKMNumericEdit }
constructor TKMNumericEdit.Create(aParent: TKMPanel; aLeft, aTop, aValueMin, aValueMax: Integer; aFont: TKMFont = fntGrey; aSelectable: Boolean = True);
var
  W: Word;
begin
  // Text width + padding + buttons
  W := Max(gRes.Fonts[fntGrey].GetTextSize(IntToStr(aValueMax)).X, gRes.Fonts[fntGrey].GetTextSize(IntToStr(aValueMin)).X) + 10 + 20 + 20;

  inherited Create(aParent, aLeft, aTop, W, 20, aFont, aSelectable);

  ReadOnly := False;

  ValueMin := aValueMin;
  ValueMax := aValueMax;
  Value := 0;

  fButtonDec := TKMButton.Create(aParent, aLeft,           aTop, 20, 20, '-', bsGame);
  fButtonInc := TKMButton.Create(aParent, aLeft + W - 20,  aTop, 20, 20, '+', bsGame);
  fButtonInc.CapOffsetY := 1;
  fButtonDec.OnClickShift := ButtonClick;
  fButtonInc.OnClickShift := ButtonClick;
  fButtonDec.OnMouseWheel := MouseWheel;
  fButtonInc.OnMouseWheel := MouseWheel;
  fButtonDec.OnClickHold := ClickHold;
  fButtonInc.OnClickHold := ClickHold;

  // Subscribe to get other controls mouse down events
  aParent.fMasterControl.AddMouseDownCtrlSub(NumEdCtrlMouseDown);
end;


procedure TKMNumericEdit.ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
var
  amt: Integer;
begin
  inherited;
  aHandled := True;

  amt := GetMultiplicator(Button);

  if Sender = fButtonDec then
    Value := Value - amt
  else
  if Sender = fButtonInc then
    Value := Value + amt;

  if (amt <> 0) and Assigned(OnChange) then
    OnChange(Self);
end;


function TKMNumericEdit.KeyDown(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  inherited KeyDown(Key, Shift);

  case Key of
    VK_UP:      begin
                  SetValueNCheckRange(Int64(Value) + 1 + 9*Byte(ssShift in Shift));
                  Changed;
                end;
    VK_DOWN:    begin
                  SetValueNCheckRange(Int64(Value) - 1 - 9*Byte(ssShift in Shift));
                  Changed;
                end;
    VK_DELETE:  ValidateText; //Update value, cause we just deleted text and KeyPress was not invoked
  end;
end;


function TKMNumericEdit.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;

  //Don't include backspace/delete because edits should always handle those. Otherwise when you
  //press backspace repeatedly to remove all characters it will apply other shortcuts like
  //resetting the zoom if you press it once too many times.
  case Key of
    VK_LEFT,
    VK_RIGHT,
    VK_HOME,
    VK_END: Result := (fText <> ''); //These keys have no effect when text is blank
  end;

  //We want these keys to be ignored by TKMNumericEdit
  if Key in [VK_F1..VK_F12, VK_ESCAPE, VK_RETURN, VK_TAB] then Result := False;

  //Ctrl can be used as an escape character, e.g. CTRL+B places beacon while chat is open
  if ssCtrl in Shift then
    Result := (Key in [VK_LEFT, VK_RIGHT, Ord('A'), Ord('C'), Ord('X'), Ord('V')]);
end;


function TKMNumericEdit.GetMaxLength: Word;
var
  minValue: Integer;
begin
  if ValueMin = Low(Integer) then
    minValue := ValueMin + 1  // to prevent integer overflow, when take Abs(MinValue);
  else
    minValue := ValueMin;

  if (Max(Abs(ValueMax), Abs(minValue)) <> 0) then
    Result := Trunc(Max(Log10(Abs(ValueMax)) + Byte(ValueMax < 0), Log10(Abs(minValue)) + Byte(minValue < 0))) + 1
  else
    Result := 1;
end;


function TKMNumericEdit.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMNumericEdit.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  inherited;

  if aHandled then Exit;

  SetValueNCheckRange(Int64(Value) + WheelSteps*(1 + 9*Byte(GetKeyState(VK_SHIFT) < 0)));

  aHandled := WheelSteps <> 0;

  Focus;

  if Assigned(OnChange) then
    OnChange(Self);
end;


procedure TKMNumericEdit.ButtonClick(Sender: TObject; Shift: TShiftState);
begin
  if Sender = fButtonDec then
    SetValueNCheckRange(Int64(Value) - GetMultiplicator(Shift))
  else
  if Sender = fButtonInc then
    SetValueNCheckRange(Int64(Value) + GetMultiplicator(Shift))
  else
    Exit;

  Focus;

  if Assigned(OnChange) then
    OnChange(Self);
end;


procedure TKMNumericEdit.SetTop(aValue: Integer);
begin
  inherited;

  fButtonDec.Top := Top;
  fButtonInc.Top := Top;
end;


procedure TKMNumericEdit.SetLeft(aValue: Integer);
begin
  inherited;

  fButtonDec.Left := Left;
  fButtonInc.Left := Left + Width - 20;
end;


procedure TKMNumericEdit.SetEnabled(aValue: Boolean);
begin
  inherited;
  fButtonDec.Enabled := fEnabled;
  fButtonInc.Enabled := fEnabled;
end;


procedure TKMNumericEdit.SetHint(const aValue: UnicodeString);
begin
  inherited;
  fButtonDec.Hint := aValue;
  fButtonInc.Hint := aValue;
end;


procedure TKMNumericEdit.SetVisible(aValue: Boolean);
begin
  inherited;
  fButtonDec.Visible := fVisible;
  fButtonInc.Visible := fVisible;
end;


function TKMNumericEdit.GetSelfAbsLeft: Integer;
begin
  Result := AbsLeft + 20;
end;


function TKMNumericEdit.GetSelfWidth: Integer;
begin
  Result := fWidth - 40;
end;


function TKMNumericEdit.IsCharValid(Key: WideChar): Boolean;
begin
  Result := SysUtils.CharInSet(Key, ['0'..'9']) or ((Key = '-') and (ValueMin < 0));
end;


procedure TKMNumericEdit.SetValueNCheckRange(aValue: Int64);
begin
  SetValue(EnsureRange(aValue, Low(Integer), High(Integer)));
end;


procedure TKMNumericEdit.SetValue(aValue: Integer);
begin
  fValue := EnsureRange(aValue, ValueMin, ValueMax);
  fText := IntToStr(fValue);

  //External Value assignment should not generate OnChange event
end;


procedure TKMNumericEdit.ValidateText(aTriggerOnChange: Boolean = True);
var
  I: Integer;
  allowedChars: TSetOfAnsiChar;
  onlyMinus, isEmpty: Boolean;
begin
  isEmpty := (fText = #8); // When deleting text with Backspace last character is still in string - backspace character (#8)

  allowedChars := ['0'..'9'];
  //Validate contents
  for I := Length(fText) downto 1 do
  begin
    if I = 1 then Include(allowedChars, '-');

    if not KromUtils.CharInSet(fText[I], allowedChars) then
    begin
      Delete(fText, I, 1);
      if CursorPos >= I then //Keep cursor in place
        CursorPos := CursorPos - 1;
    end;
  end;

  onlyMinus := (fText = '-');

  if (fText = '') or onlyMinus or isEmpty then
    Value := 0
  else
    SetValueNCheckRange(StrToInt64(fText));

  if onlyMinus then fText := '-'; //Set text back to '-' while still editing.
  if isEmpty then fText := ''; //Set text back to '' while still editing.

  CursorPos := Min(CursorPos, Length(fText)); //In case we had leading zeros in fText string

  inherited ValidateText(aTriggerOnChange); //Could trigger OnChange event
end;


procedure TKMNumericEdit.Paint;
var
  col: TColor4;
  rText: UnicodeString;
  offX: Integer;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft + 20, AbsTop, Width - 40, Height);
  if fEnabled then col:=$FFFFFFFF else col:=$FF888888;

  rText := Copy(fText, fLeftIndex+1, Length(fText)); //Remove characters to the left of fLeftIndex

  PaintSelection;

  TKMRenderUI.WriteText(AbsLeft+24, AbsTop+3, 0, fText, fFont, taLeft, col); //Characters that do not fit are trimmed

  //Render text cursor
  if (csFocus in State) and ((TimeGet div 500) mod 2 = 0) then
  begin
    SetLength(rText, CursorPos - fLeftIndex);
    offX := AbsLeft + 22 + gRes.Fonts[fFont].GetTextSize(rText).X;
    TKMRenderUI.WriteShape(offX, AbsTop+2, 3, Height-4, col, $FF000000);
  end;
end;


procedure TKMNumericEdit.CheckValueOnUnfocus;
begin
  if (fText = '-') or (fText = '') then //after unfocus, if only '-' is in string, set value to 0
    Value := 0;
end;


procedure TKMNumericEdit.FocusChanged(aFocused: Boolean);
begin
  inherited;
  if not aFocused then
    CheckValueOnUnfocus;
end;


procedure TKMNumericEdit.NumEdCtrlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if (Sender <> Self) then
    CheckValueOnUnfocus;
end;


{ TKMWareOrderRow }
constructor TKMWareOrderRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aOrderCntMax: Integer = MAX_WARES_IN_HOUSE;
                                   aOrderCntMin: Integer = 0; aImmidiateOrder: Boolean = False);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, WARE_ROW_HEIGHT);

  fWaresRow := TKMWaresRow.Create(aParent, aLeft + 68, aTop, aWidth - 68);

  fImmidiateOrder := aImmidiateOrder;

  OrderCntMin := aOrderCntMin;
  OrderCntMax := aOrderCntMax;

  fOrderRem := TKMButton.Create(aParent, aLeft,   0, 20, fHeight - 2, '-', bsGame);
  fOrderAdd := TKMButton.Create(aParent, aLeft + 46,  0, 20, fHeight - 2, '+', bsGame);
  //Label after buttons, to be sure it will be on top of them, to let player read value from it, if too long (more then 3 symbols)
  fOrderLab := TKMLabel.Create (aParent, aLeft + 33,  0, '', fntGrey, taCenter);

  fOrderAdd.CapOffsetY := 1;

  fOrderRem.OnClickShift := ButtonClick;
  fOrderAdd.OnClickShift := ButtonClick;
  fOrderRem.OnMouseWheel := MouseWheel;
  fOrderAdd.OnMouseWheel := MouseWheel;
  fWaresRow.OnMouseWheel := MouseWheel;
  fOrderRem.OnClickHold := ClickHold;
  fOrderAdd.OnClickHold := ClickHold;
end;


procedure TKMWareOrderRow.ButtonClick(Sender: TObject; Shift: TShiftState);
var
  amt: Integer;
begin
  amt := GetMultiplicator(Shift);
  if Sender = fOrderRem then
    amt := -amt;

  if amt = 0 then Exit;

  if fImmidiateOrder then
    OrderCount := fOrderCount + amt;

  Focus;

  if Assigned(OnChange) then
    OnChange(Self, amt);
end;


function TKMWareOrderRow.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMWareOrderRow.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
var
  amt: Integer;
begin
  inherited;

  if aHandled then Exit;

  amt := MouseWheelStep * WheelSteps;
  if GetKeyState(VK_SHIFT) < 0 then
    amt := amt * 10;

  if fImmidiateOrder then
    OrderCount := fOrderCount + amt;

  aHandled := amt <> 0;

  Focus;

  if Assigned(OnChange) then
    OnChange(Self, amt);
end;


procedure TKMWareOrderRow.ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
var
  amt: Integer;
begin
  inherited;
  aHandled := True;

  amt := GetMultiplicator(Button);

  if Sender = fOrderRem then
    amt := -amt;

  if amt = 0 then Exit;

  if fImmidiateOrder then
    OrderCount := fOrderCount + amt;

  if Assigned(OnChange) then
    OnChange(Self, amt);
end;


procedure TKMWareOrderRow.SetOrderCount(aValue: Integer);
begin
  fOrderCount := EnsureRange(aValue, OrderCntMin, OrderCntMax);
end;


procedure TKMWareOrderRow.SetOrderRemHint(const aValue: UnicodeString);
begin
  fOrderRem.Hint := aValue;
end;


procedure TKMWareOrderRow.SetOrderAddHint(const aValue: UnicodeString);
begin
  fOrderAdd.Hint := aValue;
end;


procedure TKMWareOrderRow.SetTop(aValue: Integer);
begin
  inherited;
  fWaresRow.Top := aValue;
end;


//Copy property to buttons
procedure TKMWareOrderRow.SetEnabled(aValue: Boolean);
begin
  inherited;
  fWaresRow.Enabled := fEnabled;
  fOrderRem.Enabled := fEnabled;
  fOrderLab.Enabled := fEnabled;
  fOrderAdd.Enabled := fEnabled;
end;


//Copy property to buttons. Otherwise they won't be rendered
procedure TKMWareOrderRow.SetVisible(aValue: Boolean);
begin
  inherited;
  fWaresRow.Visible := fVisible;
  fOrderRem.Visible := fVisible;
  fOrderLab.Visible := fVisible;
  fOrderAdd.Visible := fVisible;
end;


procedure TKMWareOrderRow.Paint;
begin
  inherited;

  fOrderRem.Top := Top + 1; //Use internal fTop instead of GetTop (which will return absolute value)
  fOrderLab.Top := Top + 4;
  fOrderAdd.Top := Top + 1;

  fOrderLab.Caption := IntToStr(OrderCount);
end;


{ TKMCostsRow }
constructor TKMCostsRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aMaxCount: Byte = 6);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  MaxCount := aMaxCount;
end;


procedure TKMCostsRow.Paint;
var
  I, gap: Integer;
begin
  inherited;
  TKMRenderUI.WriteText(AbsLeft, AbsTop + 4, Width-20, Caption, fntGrey, taLeft, $FFFFFFFF);

  if Count > 0 then
  begin
    if Count <= MaxCount then
      gap := 20
    else
      gap := Trunc(MaxCount * 20 / Count);

    if TexID1 <> 0 then
      for I := Count - 1 downto 0 do
        TKMRenderUI.WritePicture(AbsLeft+Width-gap*(I+1), AbsTop, 20, fHeight, [], RX, TexID1);
  end else
    begin
    if TexID1 <> 0 then
      TKMRenderUI.WritePicture(AbsLeft+Width-40, AbsTop, 20, fHeight, [], RX, TexID1);
    if TexID2 <> 0 then
      TKMRenderUI.WritePicture(AbsLeft+Width-20, AbsTop, 20, fHeight, [], RX, TexID2);
  end;
end;


{ TKMTrackBar }
constructor TKMTrackBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aMin, aMax: Word);
begin
  inherited Create(aParent, aLeft,aTop,aWidth,0);
  Assert(aMax > aMin, 'TKMTrackBar''s minValue >= maxValue');
  fMinValue := aMin;
  fMaxValue := aMax;
  fTrackHeight := 20;
  fRange := KMRange(aMin, aMax); //set Range before position
  Position := (fMinValue + fMaxValue) div 2;
  Caption := '';
  Font := fntMetal;
  SliderFont := fntMetal;
  CaptionWidth := -1;

  Step := 1;
  fAutoThumbWidth := False;
  fFixedThumbWidth := False;

  UpdateThumbWidth;
end;


procedure TKMTrackBar.UpdateThumbWidth;
begin
  if fFixedThumbWidth then Exit;

  if AutoThumbWidth then
    ThumbWidth := Max(gRes.Fonts[SliderFont].GetTextSize(IntToStr(MaxValue)).X,
                      gRes.Fonts[SliderFont].GetTextSize(ThumbText).X)
  else
    ThumbWidth := gRes.Fonts[SliderFont].GetTextSize(IntToStr(MaxValue)).X;

  ThumbWidth := ThumbWidth + THUMB_WIDTH_ADD;
end;


procedure TKMTrackBar.SetAutoThumbWidth(const aValue: Boolean);
begin
  fAutoThumbWidth := aValue;
  UpdateThumbWidth;
end;


procedure TKMTrackBar.SetCaption(const aValue: UnicodeString);
begin
  fCaption := aValue;

  if Trim(fCaption) <> '' then
  begin
    fHeight := 20 + fTrackHeight;
    fTrackTop := 20;
  end
  else
  begin
    fHeight := fTrackHeight;
    fTrackTop := 0;
  end;
end;


procedure TKMTrackBar.SetPosition(aValue: Word);
begin
  fPosition := KMEnsureRange(aValue, Range);
  ThumbText := IntToStr(fPosition);
end;


procedure TKMTrackBar.SetRange(const aRange: TKMRangeInt);
begin
  fRange.Min := EnsureRange(aRange.Min, MinValue, MaxValue);
  fRange.Max := EnsureRange(aRange.Max, MinValue, MaxValue);
  Position := fPosition; //Update position due to range change
end;


procedure TKMTrackBar.SetThumbText(const Value: UnicodeString);
begin
  fThumbText := Value;
  UpdateThumbWidth;
end;


procedure TKMTrackBar.ResetRange;
begin
  fRange.Min := MinValue;
  fRange.Max := MaxValue;
end;


procedure TKMTrackBar.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X, Y, Shift);
end;


procedure TKMTrackBar.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  newPos: Integer;
  posX, stepX: Single;
begin
  inherited;

  newPos := Position;
  if (ssLeft in Shift)
    and InRange(Y - AbsTop - fTrackTop, 0, fTrackHeight) then
  begin
    posX := 0;
    if AutoThumbWidth then
    begin
      stepX := (Width - ThumbWidth) / (fMaxValue - fMinValue) / Step; // width between marks
      posX := stepX * (Position / Step) + (ThumbWidth div 2); // actual marks positions on track
    end;
    if not AutoThumbWidth
      or not InRange(X - AbsLeft, posX - ThumbWidth div 2, posX + ThumbWidth div 2) then // do not update pos, if we hover over thumb
      newPos := EnsureRange(fMinValue + Round(((X-AbsLeft-ThumbWidth div 2) / (Width - ThumbWidth - 4))*(fMaxValue - fMinValue)/Step)*Step, fMinValue, fMaxValue);
  end;

  if newPos <> Position then
  begin
    Position := newPos;

    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


function TKMTrackBar.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMTrackBar.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
var
  newPos: Integer;
begin
  inherited;

  if aHandled or (WheelSteps = 0) then Exit;

  aHandled := WheelSteps <> 0;

  Focus;

  newPos := Position;

  if WheelSteps <> 0 then
    newPos := EnsureRange(newPos - Step*fMouseWheelStep*WheelSteps, fMinValue, fMaxValue);

  if newPos <> Position then
  begin
    Position := newPos;

    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


procedure TKMTrackBar.Paint;
const //Text color for disabled and enabled control
  TEXT_COLOR: array [Boolean] of TColor4 = ($FF888888, $FFFFFFFF);
var
  thumbPos, thumbHeight, rangeMinPos, rangeMaxPos: Word;
  capWidth: Integer;
begin
  inherited;

  if fCaption <> '' then
  begin
    if CaptionWidth = -1 then
      capWidth := Width
    else
      capWidth := CaptionWidth;

    TKMRenderUI.WriteText(AbsLeft, AbsTop, capWidth, fCaption, fFont, taLeft, TEXT_COLOR[fEnabled]);
  end;

  rangeMinPos := Round(Width*(fRange.Min-fMinValue) / (fMaxValue - fMinValue));
  rangeMaxPos := Round(Width*(fRange.Max-fMinValue) / (fMaxValue - fMinValue));

  TKMRenderUI.WriteBevel(AbsLeft,               AbsTop+fTrackTop+1, rangeMinPos,               fTrackHeight-2, 0, 0.3);
  TKMRenderUI.WriteBevel(AbsLeft + rangeMinPos, AbsTop+fTrackTop+2, rangeMaxPos - rangeMinPos, fTrackHeight-4);
  TKMRenderUI.WriteBevel(AbsLeft + rangeMaxPos, AbsTop+fTrackTop+1, Width - rangeMaxPos,       fTrackHeight-2, 0, 0.3);

  thumbPos := Round(Mix (0, Width - ThumbWidth, 1-(Position-fMinValue) / (fMaxValue - fMinValue)));
  thumbHeight := gRes.Sprites[rxGui].RXData.Size[132].Y;

  TKMRenderUI.WritePicture(AbsLeft + thumbPos, AbsTop+fTrackTop, ThumbWidth, thumbHeight, [anLeft,anRight], rxGui, 132);
  TKMRenderUI.WriteText(AbsLeft + thumbPos + ThumbWidth div 2, AbsTop+fTrackTop+3, 0, ThumbText, SliderFont, taCenter, TEXT_COLOR[fEnabled]);
end;


{ TKMScrollBar }
constructor TKMScrollBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aScrollAxis: TKMScrollAxis;
                                aStyle: TKMButtonStyle; aScrollStyle: TKMScrollStyle = ssGame; aPaintLevel: Integer = 0);
var
  decId, incId: Integer;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLevel);
  BackAlpha := 0.5;
  EdgeAlpha := 0.75;
  fScrollAxis := aScrollAxis;
  fMinValue := 0;
  fMaxValue := 10;
  fPosition := 0;
  fStyle    := aStyle;
  WheelStep := 1;

  if aScrollAxis = saVertical then
  begin
    fScrollDec := TKMButton.Create(Self, 0, 0, aWidth, aWidth, 591, rxGui, aStyle);
    fScrollInc := TKMButton.Create(Self, 0, aHeight-aWidth, aWidth, aWidth, 590, rxGui, aStyle);
    fScrollDec.Anchors := [anLeft, anTop, anRight];
    fScrollInc.Anchors := [anLeft, anRight, anBottom];
  end;
  if aScrollAxis = saHorizontal then
  begin
    if aScrollStyle = ssGame then
    begin
      decId := 2;
      incId := 3;
    end else begin
      decId := 674;
      incId := 675;
    end;
    fScrollDec := TKMButton.Create(Self, 0, 0, aHeight, aHeight, decId, rxGui, aStyle);
    fScrollInc := TKMButton.Create(Self, aWidth-aHeight, 0, aHeight, aHeight, incId, rxGui, aStyle);
    fScrollDec.Anchors := [anLeft, anTop, anBottom];
    fScrollInc.Anchors := [anTop, anRight, anBottom];
  end;
  fScrollDec.OnClick := DecPosition;
  fScrollDec.OnMouseWheel := MouseWheel;
  fScrollInc.OnClick := IncPosition;
  fScrollInc.OnMouseWheel := MouseWheel;
  UpdateThumbSize;
end;


procedure TKMScrollBar.SetHeight(aValue: Integer);
begin
  inherited;

  //Update Thumb size
  UpdateThumbSize;
end;


procedure TKMScrollBar.SetWidth(aValue: Integer);
begin
  inherited;

  //Update Thumb size
  UpdateThumbSize;
end;


procedure TKMScrollBar.SetEnabled(aValue: Boolean);
begin
  inherited;
  fScrollDec.Enabled := fEnabled;
  fScrollInc.Enabled := fEnabled;
end;


procedure TKMScrollBar.SetMinValue(Value: Integer);
begin
  fMinValue := Max(0, Value);
  Enabled := (fMaxValue > fMinValue);
  SetPosition(fPosition);
end;


procedure TKMScrollBar.SetMaxValue(Value: Integer);
begin
  fMaxValue := Max(0, Value);
  Enabled := (fMaxValue > fMinValue);
  SetPosition(fPosition);
end;


procedure TKMScrollBar.SetPosition(Value: Integer);
begin
  fPosition := EnsureRange(Value, fMinValue, fMaxValue);
  UpdateThumbPos;
end;


procedure TKMScrollBar.IncPosition(Sender: TObject);
begin
  SetPosition(fPosition + WheelStep);

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMScrollBar.DecPosition(Sender: TObject);
begin
  SetPosition(fPosition - WheelStep);

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMScrollBar.UpdateThumbPos;
begin
  fThumbPos := 0;

  if fMaxValue > fMinValue then
    case fScrollAxis of
      saVertical:   fThumbPos := (fPosition-fMinValue)*(Height-Width*2-fThumbSize) div (fMaxValue-fMinValue);
      saHorizontal: fThumbPos := (fPosition-fMinValue)*(Width-Height*2-fThumbSize) div (fMaxValue-fMinValue);
    end
  else
    case fScrollAxis of
      saVertical:   fThumbPos := Math.max((Height-Width*2-fThumbSize),0) div 2;
      saHorizontal: fThumbPos := Math.max((Width-Height*2-fThumbSize),0) div 2;
    end;
end;


procedure TKMScrollBar.UpdateThumbSize;
begin
  case fScrollAxis of
    saVertical:   fThumbSize := Math.max(0, (Height-2*Width)) div 4;
    saHorizontal: fThumbSize := Math.max(0, (Width-2*Height)) div 4;
  end;

  //If size has changed, then Pos needs to be updated as well (depends on it)
  UpdateThumbPos;
end;


procedure TKMScrollBar.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  T: Integer;
begin
  inherited;

  fOffset := 0;
  case fScrollAxis of
    saVertical:    begin
                      T := Y - AbsTop - Width - fThumbPos;
                      if InRange(T, 0, fThumbSize) then
                        fOffset := T - fThumbSize div 2;
                    end;
    saHorizontal:  begin
                      T := X - AbsLeft - Height - fThumbPos;
                      if InRange(T, 0, fThumbSize) then
                        fOffset := T - fThumbSize div 2;
                    end;
  end;

  MouseMove(X,Y,Shift); //Will change Position and call OnChange event
end;


procedure TKMScrollBar.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  newPos: Integer;
  T: Integer;
begin
  inherited;
  if not (ssLeft in Shift) then Exit;

  newPos := fPosition;

  case fScrollAxis of
    saVertical:
      begin
        T := Y - fOffset - AbsTop - Width;
        if InRange(T, 0, Height - Width * 2) then
          newPos := Round(fMinValue+((T - fThumbSize / 2) / (Height-Width*2-fThumbSize)) * (fMaxValue - fMinValue) );
      end;

    saHorizontal:
      begin
        T := X - fOffset - AbsLeft - Height;
        if InRange(T, 0, Width - Height * 2) then
          newPos := Round(fMinValue+((T - fThumbSize / 2) / (Width-Height*2-fThumbSize)) * (fMaxValue - fMinValue) );
      end;
  end;

  if newPos <> fPosition then
  begin
    SetPosition(newPos);
    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


function TKMScrollBar.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMScrollBar.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  inherited;

  if aHandled then Exit;

  aHandled := WheelSteps <> 0;

  if aHandled then
  begin
    Position := Position - WheelStep * WheelSteps;

    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


procedure TKMScrollBar.PaintPanel(aPaintLayer: Integer);
var
  buttonState: TKMButtonStateSet;
begin
  inherited;

  if fPaintLayer = aPaintLayer then
    case fScrollAxis of
      saVertical:   TKMRenderUI.WriteBevel(AbsLeft, AbsTop+Width, Width, Height - Width*2, EdgeAlpha, BackAlpha);
      saHorizontal: TKMRenderUI.WriteBevel(AbsLeft+Height, AbsTop, Width - Height*2, Height, EdgeAlpha, BackAlpha);
    end;

  if fMaxValue > fMinValue then
    buttonState := []
  else
    buttonState := [bsDisabled];

  if (fPaintLayer = aPaintLayer) and not (bsDisabled in buttonState) then //Only show thumb when usable
    case fScrollAxis of
      saVertical:   TKMRenderUI.Write3DButton(AbsLeft,AbsTop+Width+fThumbPos,Width,fThumbSize,rxGui,0,$FFFF00FF,buttonState,fStyle);
      saHorizontal: TKMRenderUI.Write3DButton(AbsLeft+Height+fThumbPos,AbsTop,fThumbSize,Height,rxGui,0,$FFFF00FF,buttonState,fStyle);
    end;
end;


{ TKMScrollPanel }
constructor TKMScrollPanel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aScrollAxisSet: TKMScrollAxisSet;
                                  aStyle: TKMButtonStyle; aScrollStyle: TKMScrollStyle; aEnlargeParents: Boolean = False);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fPadding := KMRect(0, 0, 0, 0);

  fScrollAxisSet := aScrollAxisSet;

  fChildsPanel := TKMPanel.Create(Self, aLeft, aTop, aWidth, aHeight);
  fChildsPanel.AnchorsStretch;
  fChildsPanel.fIsHitTestUseDrawRect := True; // We want DrawRect to be used on the ScrollPanel

  // We should create scroll bars on Parent panel, since we move panel there and back and scroll should not be scrolled as well
  fScrollBarH := TKMScrollBar.Create(aParent, aLeft, aTop + aHeight - 20, aWidth, 20, saHorizontal, aStyle, aScrollStyle);
  fScrollBarH.Hide;
  fScrollBarH.OnChange := ScrollChanged;
  fScrollBarH.WheelStep := 10;

  fScrollBarV := TKMScrollBar.Create(aParent, aLeft + aWidth - 20, aTop, 20, aHeight, saVertical, aStyle, aScrollStyle);
  fScrollBarV.Hide;
  fScrollBarV.OnChange := ScrollChanged;
  fScrollBarV.WheelStep := 10;

  fIsHitTestUseDrawRect := True; // We want DrawRect to be used on the ScrollPanel

  fScrollV_PadTop := 0;
  fScrollV_PadBottom := 0;

//  if aEnlargeParents then
//  begin
//    if saHorizontal in aScrollAxisSet then
//      Enlarge(fScrollBarH);
//
//    if saVertical in aScrollAxisSet then
//      Enlarge(fScrollBarV);
//  end;

  fClipRect := KMRect(Left, Top, Right, Bottom);
end;


function TKMScrollPanel.AddChild(aChild: TKMControl): Integer;
begin
  aChild.fIsHitTestUseDrawRect := True;
  if fChildsPanel = nil then
    Result := inherited AddChild(aChild)
  else
  begin
    Result := fChildsPanel.AddChild(aChild);

    aChild.fOnHeightChange := UpdateScrollV;
    aChild.fOnWidthChange := UpdateScrollH;
    aChild.fOnPositionSet := UpdateScrolls;
    aChild.fOnChangeVisibility := UpdateScrolls;
    aChild.fOnChangeEnableStatus := UpdateScrolls;
  end;
end;


//Update View is usefull when use Padding Left or Top
//To show panel properly initially. Beeter to invoke from Show Element
procedure TKMScrollPanel.UpdateVisibility;
begin
  inherited;
  if Visible
    and ((fPadding.Left > 0) or (fPadding.Top > 0)) then //Update visibility only when left/top padding > 0
  begin
    if saHorizontal in fScrollAxisSet then
    begin
      fScrollBarH.Position := fPadding.Left;
      ScrollChanged(fScrollBarH);
    end;

    if saVertical in fScrollAxisSet then
    begin
      fScrollBarV.Position := fPadding.Top;
      ScrollChanged(fScrollBarV);
    end;
  end;
end;


procedure TKMScrollPanel.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  if (saVertical in fScrollAxisSet) and fScrollBarV.Visible then
    fScrollBarV.MouseWheel(Sender, WheelSteps, aHandled)
  else if (saHorizontal in fScrollAxisSet) and fScrollBarH.Visible then
    fScrollBarH.MouseWheel(Sender, WheelSteps, aHandled)
  else
    inherited;
end;


procedure TKMScrollPanel.ScrollChanged(Sender: TObject);
var
  oldValue: Integer;
begin
  if Sender = fScrollBarH then
  begin
    oldValue := Left;
    Left := fClipRect.Left - fScrollBarH.Position + fPadding.Left;
    //To compensate changes in SetLeft
    Inc(fClipRect.Left, oldValue - Left);
    Inc(fClipRect.Right, oldValue - Left);
  end else
  if Sender = fScrollBarV then
  begin
    oldValue := Top;
    Top := fClipRect.Top - fScrollBarV.Position + fPadding.Top;
    //To compensate changes in SetTop
    Inc(fClipRect.Top, oldValue - Top);
    Inc(fClipRect.Bottom, oldValue - Top);
  end;
end;


procedure TKMScrollPanel.UpdateScrolls(Sender: TObject; aValue: Boolean);
begin
  // No need to update scrolls if panel is not visible
  // In case we've just hide panel then DrawRect is RECT_ZERO and scrools will be set to 0 position
  if not Visible then Exit;

  if (Sender <> fScrollBarH) and (Sender <> fScrollBarV) then
    UpdateScrolls(nil);
end;


procedure TKMScrollPanel.UpdateScrollH(Sender: TObject; aValue: Integer);
begin
  if (Sender <> fScrollBarH) then
    UpdateScrollH;
end;


procedure TKMScrollPanel.UpdateScrollH;
begin
  if not (saHorizontal in fScrollAxisSet) then Exit;

  UpdateScrollH(GetChildsRect);
end;


procedure TKMScrollPanel.UpdateScrollH(aChildsRect: TKMRect);
var
  newPos: Integer;
  showScroll: Boolean;
begin
  if not (saHorizontal in fScrollAxisSet) then Exit;

  showScroll := False;

  if aChildsRect.Width + fPadding.Left + fPadding.Right > fClipRect.Width then
  begin
    fScrollBarH.MaxValue := aChildsRect.Width - fClipRect.Width + fPadding.Left + fPadding.Right;
    newPos := fClipRect.Left - Left;

    if newPos > fScrollBarH.MaxValue then
      fLeft := Left + newPos - fScrollBarH.MaxValue; //Slightly move panel to the top, when resize near maxvalue position
    showScroll := True;
  end else begin
    fScrollBarH.Position := 0;
    if Left <> fClipRect.Left then
      fLeft := fClipRect.Left; //Set directrly to avoid SetLeft call
  end;

  fScrollBarH.Width := Width;
  if showScroll <> fScrollBarH.Visible then
  begin
    fScrollBarH.Visible := showScroll;
    fChildsPanel.Height := Height - 20*Byte(showScroll);
  end;
end;


procedure TKMScrollPanel.UpdateScrollV(Sender: TObject; aValue: Integer);
begin
  if (Sender <> fScrollBarV) then
    UpdateScrollV;
end;


procedure TKMScrollPanel.UpdateScrollV;
begin
  if not (saVertical in fScrollAxisSet) then Exit;

  UpdateScrollV(GetChildsRect);
end;


procedure TKMScrollPanel.UpdateScrollV(aChildsRect: TKMRect);
var
  newPos: Integer;
  showScroll: Boolean;
begin
  if not (saVertical in fScrollAxisSet) then Exit;

  //Do not set Visible, avoid trigger OnChangeVisibility
  showScroll := False;

  if aChildsRect.Height + fPadding.Top + fPadding.Bottom > fClipRect.Height then
  begin
    fScrollBarV.MaxValue := aChildsRect.Height - fClipRect.Height + fPadding.Top + fPadding.Bottom;
    newPos := fClipRect.Top - Top;

    if newPos > fScrollBarV.MaxValue then
      fTop := Top + newPos - fScrollBarV.MaxValue; //Slightly move panel to the top, when resize near maxvalue position
    showScroll := True;
  end else begin
    fScrollBarV.Position := 0;
    if Top <> fClipRect.Top then
      fTop := fClipRect.Top; //Set directrly to avoid SetTop call
  end;

  fScrollBarV.Height := Height - fScrollV_PadTop - fScrollV_PadBottom;
  if showScroll <> fScrollBarV.Visible then
  begin
    fScrollBarV.Visible := showScroll;
    fChildsPanel.Width := Width - 20*Byte(showScroll);
  end;
end;


procedure TKMScrollPanel.UpdateScrolls(Sender: TObject);
var
  childsRect: TKMRect;
begin
  childsRect := GetChildsRect;

  UpdateScrollV(childsRect);
  UpdateScrollH(childsRect);
end;


procedure TKMScrollPanel.SetLeft(aValue: Integer);
var
  oldValue: Integer;
begin
  oldValue := Left;
  inherited;

  Inc(fClipRect.Left, Left - oldValue);
  Inc(fClipRect.Right, Left - oldValue);

  UpdateScrolls(nil);
end;


procedure TKMScrollPanel.SetScrollVPadBottom(const Value: Integer);
begin
  fScrollV_PadBottom := Value;
  fScrollBarV.Height := fScrollBarV.Height - Value;
end;


procedure TKMScrollPanel.SetScrollVPadTop(const Value: Integer);
begin
  fScrollV_PadTop := Value;
  fScrollBarV.Top := fScrollBarV.Top + Value;
  fScrollBarV.Height := fScrollBarV.Height - Value;
end;


procedure TKMScrollPanel.SetTop(aValue: Integer);
var
  oldValue: Integer;
begin
  oldValue := Top;
  inherited;

  Inc(fClipRect.Top, Top - oldValue);
  Inc(fClipRect.Bottom, Top - oldValue);

  UpdateScrolls(nil);
end;


procedure TKMScrollPanel.SetVisible(aValue: Boolean);
begin
  inherited;

  // Hide ScrollBars with if we hide ScrollPanel
  if not aValue then
  begin
    fScrollBarH.Visible := aValue;
    fScrollBarV.Visible := aValue;
  end;
end;


procedure TKMScrollPanel.SetWidth(aValue: Integer);
var
  oldValue: Integer;
begin
  oldValue := Width;
  inherited;

  Inc(fClipRect.Right, Width - oldValue);

  fScrollBarV.Left := fClipRect.Left + Width;

  UpdateScrolls(nil);
end;


procedure TKMScrollPanel.SetHeight(aValue: Integer);
var
  oldValue: Integer;
begin
  oldValue := Height;
  inherited;

  Inc(fClipRect.Bottom, Height - oldValue);

  fScrollBarH.Top := fClipRect.Top + Height;

  UpdateScrolls(nil);
end;


function TKMScrollPanel.GetChildsRect: TKMRect;
var
  I: Integer;
begin
  Result := KMRECT_ZERO; //Zero rect, by default

  for I := 0 to fChildsPanel.ChildCount - 1 do
  begin
    if not fChildsPanel.Childs[I].IsPainted then
      Continue;

    if fChildsPanel.Childs[I].Left < Result.Left then
      Result.Left := fChildsPanel.Childs[I].Left;

    if fChildsPanel.Childs[I].Top < Result.Top then
      Result.Top := fChildsPanel.Childs[I].Top;

    if fChildsPanel.Childs[I].Right > Result.Right then
      Result.Right := fChildsPanel.Childs[I].Right;

    if fChildsPanel.Childs[I].Bottom > Result.Bottom then
      Result.Bottom := fChildsPanel.Childs[I].Bottom;
  end;
end;


function TKMScrollPanel.AllowScrollV: Boolean;
begin
  Result := saVertical in fScrollAxisSet;
end;


function TKMScrollPanel.AllowScrollH: Boolean;
begin
  Result := saHorizontal in fScrollAxisSet;
end;


function TKMScrollPanel.GetDrawRect: TKMRect;
begin
  Result := KMRect(AbsDrawLeft, AbsDrawTop, AbsDrawRight, AbsDrawBottom);
end;

function TKMScrollPanel.GetAbsDrawLeft: Integer;
begin
  Result := Parent.AbsLeft + fClipRect.Left;
end;

function TKMScrollPanel.GetAbsDrawTop: Integer;
begin
  Result := Parent.AbsTop + fClipRect.Top;
end;

function TKMScrollPanel.GetAbsDrawRight: Integer;
begin
  Result := Parent.AbsLeft + fClipRect.Right + 20*Byte(AllowScrollV and not fScrollBarV.Visible);
end;

function TKMScrollPanel.GetAbsDrawBottom: Integer;
begin
  Result := Parent.AbsTop + fClipRect.Bottom + 20*Byte(AllowScrollH and not fScrollBarH.Visible);
end;


procedure TKMScrollPanel.PaintPanel(aPaintLayer: Integer);
begin
  TKMRenderUI.SetupClipX(AbsDrawLeft, AbsDrawRight);
  TKMRenderUI.SetupClipY(AbsDrawTop, AbsDrawBottom);

  inherited;

  TKMRenderUI.ReleaseClipY;
  TKMRenderUI.ReleaseClipX;
end;


{ TKMMemo }
constructor TKMMemo.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle; aSelectable: Boolean = True);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fItemHeight := 20;
  fItems := TStringList.Create;
  fFont := aFont;

  fScrollBar := TKMScrollBar.Create(aParent, aLeft+aWidth-20, aTop, 20, aHeight, saVertical, aStyle);
  UpdateScrollBar; //Initialise the scrollbar
  fSelectable := aSelectable;

  // Subscribe to get other controls mouse move events
  aParent.fMasterControl.AddMouseDownCtrlSub(ControlMouseDown);
end;


destructor TKMMemo.Destroy;
begin
  fItems.Free;
  inherited;
end;


procedure TKMMemo.SetHeight(aValue: Integer);
begin
  inherited;
  fScrollBar.Height := fHeight;
  UpdateScrollBar; //Since height has changed
end;


procedure TKMMemo.SetWidth(aValue: Integer);
begin
  inherited;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
  ReformatText; //Repositions the scroll bar as well
end;


//Copy property to scrollbar. Otherwise it won't be rendered
procedure TKMMemo.SetVisible(aValue: Boolean);
begin
  inherited;

  //Hide scrollbar and its buttons
  fScrollBar.Visible := fVisible and (fScrollBar.MaxValue <> fScrollBar.MinValue);
end;


function TKMMemo.GetTopIndex: smallint;
begin
  Result := fScrollBar.Position;
end;


procedure TKMMemo.SetTopIndex(aIndex: smallint);
begin
  fScrollBar.Position := aIndex;
end;


procedure TKMMemo.SetEnabled(aValue: Boolean);
begin
  inherited;
  fScrollBar.Enabled := fEnabled;
end;


procedure TKMMemo.SetTop(aValue: Integer);
begin
  inherited;
  fScrollBar.Top := Top;
end;


procedure TKMMemo.SetAutoWrap(const Value: boolean);
begin
  fAutoWrap := Value;
  ReformatText;
end;


procedure TKMListBox.SetItemHeight(const Value: byte);
begin
  fItemHeight := Value;
  UpdateScrollBar;
end;


function TKMMemo.GetText: UnicodeString;
begin
  Result := fText;
end;


procedure TKMMemo.SetText(const aText: UnicodeString);
begin
  fText := aText;
  ReformatText;

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMMemo.ReformatText;
var
  newText: UnicodeString;
begin
  if fAutoWrap then
    newText := gRes.Fonts[fFont].WordWrap(fText, fWidth - fScrollBar.Width - 8, True, IndentAfterNL)
  else
    newText := fText;

  //KaM uses | for new line, fItems.Text:= uses standard eol to parse each item from the string
  fItems.Text := StringReplace(newText, '|', EolW, [rfReplaceAll]);
  UpdateScrollBar;
end;


function TKMMemo.GetVisibleRows: Integer;
begin
  Result := fHeight div fItemHeight;
end;


//fItems.Count or Height has changed
procedure TKMMemo.UpdateScrollBar;
var
  oldMax: Integer;
begin
  oldMax := fScrollBar.MaxValue;
  fScrollBar.MaxValue := fItems.Count - GetVisibleRows;
  fScrollBar.Visible := fVisible and (fScrollBar.MaxValue <> fScrollBar.MinValue);

  if fScrollDown then
  begin
    if oldMax-fScrollBar.Position <= 2 then //If they were near the bottom BEFORE updating, keep them at the bottom
      SetTopIndex(fItems.Count) //This puts it at the bottom because of the EnsureRange in SetTopIndex
  end
  else
    SetTopIndex(0);
end;


procedure TKMMemo.SetCursorPos(aPos: Integer);
begin
  fCursorPos := EnsureRange(aPos, 0, GetMaxCursorPos);
end;


function TKMMemo.GetPlainText(aUsePipeAsEOL: Boolean; aStart: Integer = -1; aEnd: Integer = -1): UnicodeString;
begin
  if aStart = -1 then
    aStart := 0;

  if aEnd = -1 then
    aEnd := Length(fItems.Text);

  // First remove EOL's to get correct positions in text
  Result := StringReplace(fItems.Text, EolW, '|', [rfReplaceAll]);
  // Get text with selected positions, cleaned of color markup
  Result := Copy(GetNoColorMarkupText(Result), aStart + 1, aEnd - aStart);
  // Return EOL's back
  if not aUsePipeAsEOL then
    Result := StringReplace(Result, '|', EolW, [rfReplaceAll]);
end;


function TKMMemo.GetSelectedText: UnicodeString;
begin
  Result := '';
  if HasSelection then
    Result := GetPlainText(False, fSelectionStart, fSelectionEnd);
end;


function TKMMemo.HasSelection: Boolean;
begin
  Result := (fSelectionStart <> -1) and (fSelectionEnd <> -1) and (fSelectionStart <> fSelectionEnd);
end;


procedure TKMMemo.ResetSelection;
begin
  fSelectionStart := -1;
  fSelectionEnd := -1;
  fSelectionInitialPos := -1;
end;


//We are using 2 systems for position: Linear (cumulative) and 'Point' (2D with column and row)
//Every system have Length(RowText)+1 positions in every line
//Convert Linear position into 2D position
function TKMMemo.LinearToPointPos(aPos: Integer): TKMPoint;
var I, row, column: Integer;
    rowText: UnicodeString;
    rowStartPos, rowEndPos: Integer;
begin
  row := 0;
  column := 0;
  for I := 0 to fItems.Count - 1 do
  begin
    rowText := GetNoColorMarkupText(fItems[I]);
    rowStartPos := PointToLinearPos(0, I);
    rowEndPos := rowStartPos + Length(rowText);
    if InRange(aPos, rowStartPos, rowEndPos) then
    begin
      row := I;
      column := aPos - rowStartPos;
      Break;
    end;
  end;
  Result := KMPoint(column, row);
end;


//We are using 2 systems for position: Linear (cumulative) and 'Point' (2D with column and row)
//Every system have Length(RowText)+1 positions in every line
//Convert 2D position into Linear position
function TKMMemo.PointToLinearPos(aColumn, aRow: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  aRow := EnsureRange(aRow, 0, fItems.Count-1);
  for I := 0 to aRow-1 do
    Inc(Result, Length(GetNoColorMarkupText(fItems[I])) + 1); //+1 for special KaM new line symbol ('|')
  Inc(Result, EnsureRange(aColumn, 0, GetMaxPosInRow(aRow)));
end;


//Return position of Cursor in 2D of point X,Y on the screen
function TKMMemo.GetCharPosAt(X,Y: Integer): TKMPoint;
var
  row, column: Integer;
begin
  row := 0;
  column := 0;

  if fItems.Count > 0 then
  begin
    row := (EnsureRange(Y-AbsTop-3, 0, fHeight-6) div fItemHeight) + TopIndex;
    row := EnsureRange(row, 0, fItems.Count-1);
    column := gRes.Fonts[fFont].CharsThatFit(GetNoColorMarkupText(fItems[row]), X-AbsLeft-4);
  end;
  Result := KMPoint(column, row);
end;


//Return position of Cursor in linear system of point X,Y on the screen
function TKMMemo.GetCursorPosAt(X,Y: Integer): Integer;
var
  charPos: TKMPoint;
begin
  charPos := GetCharPosAt(X, Y);
  Result := PointToLinearPos(charPos.X, charPos.Y);
end;


// Maximum possible position of Cursor
function TKMMemo.GetMaxCursorPos: Integer;
begin
  Result := Length(StringReplace(fItems.Text, EolW, '', [rfReplaceAll])) + EnsureRange(fItems.Count-1, 0, fItems.Count);
end;


// Minimum possible position of Cursor in its current Row
function TKMMemo.GetMinCursorPosInRow: Integer;
begin
  Result := GetMinPosInRow(LinearToPointPos(CursorPos).Y)
end;


// Maximum possible position of Cursor in its current Row
function TKMMemo.GetMaxCursorPosInRow: Integer;
begin
  Result := GetMaxPosInRow(LinearToPointPos(CursorPos).Y)
end;


// Minimum possible position of Cursor in the specified aRow
function TKMMemo.GetMinPosInRow(aRow: Integer): Integer;
begin
  if aRow = 0 then
    Result := 0
  else
    Result := GetMaxPosInRow(aRow - 1) + 1;
end;


// Maximum possible position of Cursor in the specified aRow
function TKMMemo.GetMaxPosInRow(aRow: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to min(aRow, fItems.Count - 1) do
    Inc(Result, Length(GetNoColorMarkupText(fItems[I])) + 1);
  Result := EnsureRange(Result - 1, 0, Result);
end;


procedure TKMMemo.SetSelectionStart(aValue: Integer);
var
  maxPos: Integer;
begin
  if fSelectable then
  begin
    maxPos := GetMaxCursorPos;
    fSelectionStart := EnsureRange(aValue, 0, maxPos);
  end;
end;


procedure TKMMemo.SetSelectionEnd(aValue: Integer);
var
  maxPos: Integer;
begin
  if fSelectable then
  begin
    maxPos := GetMaxCursorPos;
    fSelectionEnd := EnsureRange(aValue, 0, maxPos);
  end;
end;


//Set selections with pair of value, using he fact, that fSelectionStart <= fSelectionEnd
procedure TKMMemo.SetSelections(aValue1, aValue2: Integer);
begin
  fSelectionStart := Min(aValue1, aValue2);
  fSelectionEnd := Max(aValue1, aValue2);
end;


//Update selection start/end due to change cursor position
procedure TKMMemo.UpdateSelection(aOldCursorPos: Integer; aIsSelecting: Boolean);
begin
  if aIsSelecting then
  begin
    if HasSelection then
    begin
      if aOldCursorPos = SelectionStart then
        SetSelections(CursorPos, SelectionEnd)
      else
      if aOldCursorPos = SelectionEnd then
        SetSelections(SelectionStart, CursorPos);
    end else
      SetSelections(aOldCursorPos, CursorPos);
  end
  else
    ResetSelection;
end;


procedure TKMMemo.Add(const aItem: UnicodeString);
begin
  if fText <> '' then
    fText := fText + '|';

  fText := fText + aItem; //Append the new string

  SetText(fText); //Updates the text in fItems
  UpdateScrollBar; //Scroll down with each item that is added.

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMMemo.Clear;
begin
  fText := '';
  fItems.Clear;
  ResetSelection;
  UpdateScrollBar;

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMMemo.ScrollToBottom;
begin
  SetTopIndex(fItems.Count);
end;


//Key events which have no effect should not be handled (allows scrolling while chat window open with no text entered)
function TKMMemo.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;

  //Don't include backspace/delete because edits should always handle those. Otherwise when you
  //press backspace repeatedly to remove all characters it will apply other shortcuts like
  //resetting the zoom if you press it once too many times.
  case Key of
    VK_UP,
    VK_DOWN,
    VK_LEFT,
    VK_RIGHT,
    VK_HOME,
    VK_END,
    VK_PRIOR,
    VK_NEXT: Result := (fText <> ''); //These keys have no effect when text is blank
  end;

  //We want these keys to be ignored by chat, so game shortcuts still work
  if Key in [VK_F1..VK_F12, VK_ESCAPE] then Result := False;

  //Ctrl can be used as an escape character, e.g. CTRL+B places beacon while chat is open
  if ssCtrl in Shift then Result := (Key in [VK_LEFT, VK_RIGHT, Ord('A'), Ord('C'), Ord('X')]);
end;


function TKMMemo.KeyDown(Key: Word; Shift: TShiftState): Boolean;
  //Move cursor vertically (change cursor row)
  procedure MoveCursorVertically(aRowIncrement: Integer);
  var
    cursorPointPos: TKMPoint;
    newCursorPosY: Integer;
    srcLineText, destLineText: UnicodeString;
  begin
    cursorPointPos := LinearToPointPos(CursorPos);
    newCursorPosY := EnsureRange(cursorPointPos.Y + aRowIncrement, 0, fItems.Count-1);
    if newCursorPosY <> cursorPointPos.Y then
    begin
      // Because we don't use monospaces fonts, then its better to find proper column, which depends of text width in px
      srcLineText := GetNoColorMarkupText(Copy(fItems[cursorPointPos.Y], 1, cursorPointPos.X));
      destLineText := GetNoColorMarkupText(fItems[newCursorPosY]);
      //Use 'rounding' version of CharsThatFit to get more precise position
      cursorPointPos.X := gRes.Fonts[fFont].CharsThatFit(destLineText, gRes.Fonts[fFont].GetTextSize(srcLineText).X, True);
      CursorPos := PointToLinearPos(cursorPointPos.X, newCursorPosY);
      // Update scroll position, if needed
      if TopIndex > newCursorPosY then
        TopIndex := newCursorPosY
      else if TopIndex < newCursorPosY - GetVisibleRows + 1 then
        TopIndex := newCursorPosY - GetVisibleRows + 1;
    end;
  end;

  // Update cursor pos considering Ctrl Key to go to the next / prev word in the text
  procedure UpdateCursorPos(aCursorDir: TKMCursorDir);
  begin
    if ssCtrl in Shift then
    begin
      case aCursorDir of
        cdNone:     ;
        cdForward:  CursorPos := GetNextWordPos(GetPlainText(True), CursorPos);
        cdBack:     CursorPos := GetPrevWordPos(GetPlainText(True), CursorPos);
      end;
    end
    else
      CursorPos := CursorPos + ShortInt(aCursorDir);
  end;

var
  oldCursorPos: Integer;
  isSelect: Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyDown(Key, Shift) then Exit;

  //Clipboard operations
  if (Shift = [ssCtrl]) and (Key <> VK_CONTROL) then
    case Key of
      Ord('A'): SetSelections(0, GetMaxCursorPos);
      Ord('C'),
      Ord('X'): if HasSelection then
                  Clipboard.AsText := GetSelectedText;
    end;

  oldCursorPos := CursorPos;
  isSelect := IsSelecting(Key, Shift);

  case Key of
    VK_LEFT,
    VK_RIGHT: begin
                UpdateCursorPos(GetCursorDir(Key));
                UpdateSelection(oldCursorPos, isSelect);
              end;
    VK_UP:    begin
                MoveCursorVertically(-1);
                UpdateSelection(oldCursorPos, isSelect);
              end;
    VK_DOWN:  begin
                MoveCursorVertically(1);
                UpdateSelection(oldCursorPos, isSelect);
              end;
    VK_PRIOR: begin
                MoveCursorVertically(-GetVisibleRows);
                UpdateSelection(oldCursorPos, isSelect);
              end;
    VK_NEXT:  begin
                MoveCursorVertically(GetVisibleRows);
                UpdateSelection(oldCursorPos, isSelect);
              end;
    VK_HOME:  begin
                CursorPos := GetMinCursorPosInRow;
                UpdateSelection(oldCursorPos, isSelect);
              end;
    VK_END:   begin
                CursorPos := GetMaxCursorPosInRow;
                UpdateSelection(oldCursorPos, isSelect);
              end;
  end
end;


function TKMMemo.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := inherited KeyUp(Key, Shift) or KeyEventHandled(Key, Shift);
end;


function TKMMemo.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMMemo.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  inherited;

  if aHandled then Exit;

  SetTopIndex(TopIndex - WheelSteps);

  aHandled := WheelSteps <> 0;
end;


procedure TKMMemo.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  oldCursorPos: Integer;
begin
  inherited;

  Focusable := fSelectable and (fText <> ''); // Do not focus on empty Memo's
  // Update Focus now, because we need to focus on MouseDown, not on MouseUp as by default for all controls
  MasterParent.fMasterControl.UpdateFocus(Self);

  oldCursorPos := CursorPos;
  CursorPos := GetCursorPosAt(X, Y);

  if Focusable then
  begin
    //Try select on Shift + LMB click
    UpdateSelection(oldCursorPos, (oldCursorPos <> -1) and (Shift = [ssLeft, ssShift]));
    fSelectionInitialPos := CursorPos;
  end;
end;


procedure TKMMemo.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  oldCursorPos: Integer;
  charPos: TKMPoint;
begin
  inherited;
  if (ssLeft in Shift) and (fSelectionInitialPos <> -1) then
  begin
    charPos := GetCharPosAt(X, Y);

    // To rotate text to top while selecting
    if (Y-AbsTop-3 < 0) and (TopIndex > 0) then
    begin
      Dec(charPos.Y);
      SetTopIndex(TopIndex-1);
    end;
    // To rotate text to bottom while selecting
    if (Y-AbsTop-3 > fHeight)
      and (fScrollBar.Position < fScrollBar.MaxValue) then
    begin
      charPos.Y := EnsureRange(charPos.Y+1, 0, fItems.Count);
      SetTopIndex(TopIndex+1);
    end;

    oldCursorPos := CursorPos;
    CursorPos := PointToLinearPos(charPos.X, charPos.Y);;
    UpdateSelection(oldCursorPos, True);
  end;
end;


procedure TKMMemo.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  fSelectionInitialPos := -1;
end;


procedure TKMMemo.ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  // Reset all, if other control was clicked
  if Sender <> Self then
  begin
    ResetSelection;
    Focusable := False;
    CursorPos := -1;
    MasterParent.fMasterControl.UpdateFocus(Self);
  end;
end;


procedure TKMMemo.FocusChanged(aFocused: Boolean);
begin
  if not aFocused then
  begin
    ResetSelection;
    CursorPos := -1;
    Focusable := False;
  end;
end;


procedure TKMMemo.Paint;
var
  I, paintWidth, selPaintTop, selPaintHeight: Integer;
  beforeSelectionText, selectionText, rowText: UnicodeString;
  beforeSelectionW, selectionW, selStartPosInRow, selEndPosInRow, rowStartPos, rowEndPos: Integer;
  offX, offY: Integer;
begin
  inherited;
  if fScrollBar.Visible then
    paintWidth := Width - fScrollBar.Width //Leave space for scrollbar
  else
    paintWidth := Width; //List takes up the entire width

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, paintWidth, Height, 1, 0.5);

  for I := 0 to Math.min(fItems.Count-1, GetVisibleRows - 1) do
  begin
    rowText := GetNoColorMarkupText(fItems[TopIndex+I]);
    rowStartPos := PointToLinearPos(0, TopIndex+I);
    rowEndPos := rowStartPos + Length(rowText);
    if HasSelection then
    begin
      selStartPosInRow := fSelectionStart - rowStartPos;
      selEndPosInRow := fSelectionEnd - rowStartPos;

      selStartPosInRow := EnsureRange(selStartPosInRow, 0, rowEndPos);
      selEndPosInRow := EnsureRange(selEndPosInRow, selStartPosInRow, rowEndPos);

      if selStartPosInRow <> selEndPosInRow then
      begin
        beforeSelectionText := Copy(rowText, 1, selStartPosInRow);
        selectionText := Copy(rowText, selStartPosInRow+1, selEndPosInRow - selStartPosInRow);

        beforeSelectionW := gRes.Fonts[fFont].GetTextSize(beforeSelectionText).X;
        selectionW := gRes.Fonts[fFont].GetTextSize(selectionText).X;

        selPaintHeight := fItemHeight;
        selPaintTop := AbsTop+I*fItemHeight;
        if I = 0 then
        begin
          Dec(selPaintHeight, 3);
          Inc(selPaintTop, 3);
        end;

        TKMRenderUI.WriteShape(AbsLeft+4+beforeSelectionW, selPaintTop, min(selectionW, Width-8), selPaintHeight, clTextSelection);
      end;
    end;

    //Render text cursor
    if fSelectable and (csFocus in State) and ((TimeGet div 500) mod 2 = 0)
      and InRange(CursorPos, rowStartPos, rowEndPos) then
    begin
      offX := AbsLeft + 2 + gRes.Fonts[fFont].GetTextSize(Copy(rowText, 1, CursorPos-rowStartPos)).X;
      offY := AbsTop + 2 + I*fItemHeight;
      TKMRenderUI.WriteShape(offX, offY, 3, fItemHeight-4, $FFFFFFFF, $FF000000);
    end;
    TKMRenderUI.WriteText(AbsLeft+4, AbsTop+I*fItemHeight+3, Width-8, fItems.Strings[TopIndex+I] , fFont, taLeft);
  end;

end;


{ TKMListBox }
constructor TKMListBox.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle;
                              aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);
  fBackAlpha := 0.5;
  fItemHeight := 20;
  fItemIndex := -1;
  fItems := TStringList.Create;
  fFont := aFont;
  fAutoHideScrollBar := False; //Always show the scrollbar by default, then it can be turned off if required
  fShowHintWhenShort := False;
  Focusable := True; //For up/down keys
  fSeparatorHeight := 0;
  fSeparatorTexts := TStringList.Create;
  fSeparatorFont := fntAntiqua; //Looks good on dark solid background
  fSeparatorColor := clListSeparatorShape;
  fSearchEnabled := False;

  fScrollBar := TKMScrollBar.Create(aParent, aLeft+aWidth-20, aTop, 20, aHeight, saVertical, aStyle);
  UpdateScrollBar; //Initialise the scrollbar
end;


destructor TKMListBox.Destroy;
begin
  fSeparatorTexts.Free;
  fItems.Free;
  inherited;
end;


function TKMListBox.CanSearch: Boolean;
begin
  Result := fSearchEnabled;
end;


function TKMListBox.GetRowCount: Integer;
begin
  Result := fItems.Count;
end;


procedure TKMListBox.SetItemIndex(aIndex: Integer);
begin
  if InRange(aIndex, 0, GetRowCount - 1) then
    fItemIndex := aIndex
  else
    fItemIndex := -1;
end;


function TKMListBox.GetItemIndex: Integer;
begin
  Result := fItemIndex;
end;


function TKMListBox.GetItemString(aIndex: Integer): UnicodeString;
begin
  Result := fItems[aIndex];
end;


procedure TKMListBox.SetLeft(aValue: Integer);
begin
  inherited;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
end;


procedure TKMListBox.SetTop(aValue: Integer);
begin
  inherited;
  fScrollBar.Top := Top;
end;


procedure TKMListBox.SetHeight(aValue: Integer);
begin
  inherited;
  fScrollBar.Height := fHeight;
  UpdateScrollBar; //Since height has changed
end;


//Copy property to scrollbar. Otherwise it won't be rendered
procedure TKMListBox.SetVisible(aValue: Boolean);
begin
  inherited;
  fScrollBar.Visible := fVisible and (not fAutoHideScrollBar or fScrollBar.Enabled); //Hide scrollbar and its buttons
end;


function TKMListBox.GetSelfWidth: Integer;
begin
  if fScrollBar.Visible then
    Result := Width - fScrollBar.Width //Leave space for scrollbar
  else
    Result := Width; //List takes up the entire width
end;


function TKMListBox.GetTopIndex: Integer;
begin
  Result := fScrollBar.Position;
end;


procedure TKMListBox.SetTopIndex(aIndex: Integer);
begin
  fScrollBar.Position := aIndex;
end;


procedure TKMListBox.SetBackAlpha(aValue: single);
begin
  fBackAlpha := aValue;
  fScrollBar.BackAlpha := aValue;
end;


procedure TKMListBox.SetEnabled(aValue: Boolean);
begin
  inherited;
  fScrollBar.Enabled := fEnabled;
end;


//fItems.Count has changed
procedure TKMListBox.UpdateScrollBar;
begin
  fScrollBar.MaxValue := fItems.Count - GetVisibleRows;
  fScrollBar.Visible := fVisible and (not fAutoHideScrollBar or fScrollBar.Enabled);
  //Separators can not be used with scroll bar for now.
  //Scrollbar works line-wise, not pixel-wise,
  //so adding separators could cause visual issues
  //(list 'jumping' when there is or there is no separator, when separator width is not equal to line width)
  Assert(not (fScrollBar.Visible and (SeparatorsCount > 0)), 'Separators can not be used with scroll bar');
end;


procedure TKMListBox.Add(const aItem: UnicodeString; aTag: Integer = 0);
begin
  fItems.Add(aItem);
  SetLength(ItemTags, Length(ItemTags) + 1);
  ItemTags[Length(ItemTags)-1] := aTag;
  UpdateScrollBar;
end;


//Add separator just before aPosition item in list with aText on it
procedure TKMListBox.AddSeparator(aPosition: Integer; const aText: String = '');
begin
  fSeparatorTexts.Add(aText);
  SetLength(fSeparatorPositions, Length(fSeparatorPositions) + 1);
  fSeparatorPositions[Length(fSeparatorPositions)-1] := aPosition;
  //Separators can not be used with scroll bar for now.
  //Scrollbar works line-wise, not pixel-wise,
  //so adding separators could cause visual issues
  //(list 'jumping' when there is or there is no separator, when separator width is not equal to line width)
  Assert(not fScrollBar.Visible, 'Separators can not be used with scroll bar');
end;


procedure TKMListBox.ClearSeparators;
begin
  fSeparatorTexts.Clear;
  SetLength(fSeparatorPositions, 0);
end;


procedure TKMListBox.Clear;
begin
  fItems.Clear;
  SetLength(ItemTags, 0);
  ClearSeparators;
  fItemIndex := -1;
  UpdateScrollBar;
end;


//Hide the scrollbar if it is not required (disabled) This is used for drop boxes.
procedure TKMListBox.SetAutoHideScrollBar(Value: boolean);
begin
  fAutoHideScrollBar := Value;
  UpdateScrollBar;
end;


function TKMListBox.Count: Integer;
begin
  Result := fItems.Count;
end;


function TKMListBox.Selected: Boolean;
begin
  Result := fItemIndex <> -1;
end;


function TKMListBox.SeparatorsCount: Integer;
begin
  Result := Length(fSeparatorPositions);
end;


function TKMListBox.GetVisibleRows: Integer;
begin
  Result := (fHeight - fSeparatorHeight*SeparatorsCount) div fItemHeight;
end;


function TKMListBox.GetHint: UnicodeString;
var
  hintStr: string;
begin
  Result := inherited GetHint;

  if not fShowHintWhenShort or (fMouseOverRow = -1) then Exit;

  if Result = '' then
  begin
    if //Got crashed sometimes when mouse over empty disabled ComboBox with Header (fMouseOverCell = [0;0])
      fItems.Count > fMouseOverRow then
    begin
      hintStr := fItems[fMouseOverRow];
      // Show hint, if caption does not fit into the cell
      if gRes.Fonts[fFont].GetTextSize(hintStr).X > RenderTextWidth then
        Result := hintStr;
    end;
  end;
end;


function TKMListBox.GetHintBackRect: TKMRect;
const
  SELECT_PAD = 1;
var
  top: Integer;
begin
  if fMouseOverRow = -1 then Exit(KMRECT_ZERO);

  top := GetItemTop(fMouseOverRow) - GetItemTop(TopIndex) - SELECT_PAD;
  Result := KMRect(-1, top, PaintWidth, top + fItemHeight + SELECT_PAD);
end;


function TKMListBox.GetHintTextOffset: TKMPoint;
begin
  if fMouseOverRow = -1 then Exit(KMPOINT_ZERO);

  Result := KMPoint(TXT_PAD_X, TXT_PAD_Y + GetItemTop(fMouseOverRow) - GetItemTop(TopIndex));
end;


function TKMListBox.GetItem(aIndex: Integer): UnicodeString;
begin
  Result := fItems[aIndex];
end;


function TKMListBox.GetSeparatorPos(aIndex: Integer): Integer;
begin
  Result := fSeparatorPositions[aIndex];
end;


//Get aIndex item top position, considering separators
function TKMListBox.GetItemTop(aIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := fItemHeight*aIndex;
  for I := 0 to Length(fSeparatorPositions) - 1 do
    if fSeparatorPositions[I] <= aIndex then
      Inc(Result, fSeparatorHeight);
end;


function TKMListBox.GetMouseOverRow: Integer;
begin
  Result := fMouseOverRow;
end;


function TKMListBox.GetPaintWidth: Integer;
begin
  Result := Width - fScrollBar.Width * Byte(fScrollBar.Visible);
end;


function TKMListBox.GetRenderTextWidth: Integer;
begin
  Result := PaintWidth - 2*TXT_PAD_X;
end;


procedure TKMListBox.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X,Y,Shift); //Will change Position and call OnChange event
end;


procedure TKMListBox.MouseMove(X,Y: Integer; Shift: TShiftState);

  // We should use this function, to go from 1st line to the next lines, because we could have separators in the list
  function GetItemOverIndex(aY: Integer): Integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := 0 to Min(fItems.Count, GetVisibleRows) - 1 do
      if InRange(aY, AbsTop + GetItemTop(I), AbsTop + GetItemTop(I) + fItemHeight) then
        Exit(I);
  end;

var
  newIndex: Integer;
begin
  inherited;

  fMouseOverRow := -1;

  if   not InRange(X, AbsLeft, AbsLeft + Width - (fScrollBar.Width * Byte(fScrollBar.Visible)))
    or not InRange(Y, AbsTop, AbsTop + Height) then Exit;

  fMouseOverRow := GetItemOverIndex(Y);

  if fMouseOverRow <> -1 then
    fMouseOverRow := fMouseOverRow + TopIndex
  else
    Exit;

  if (ssLeft in Shift) then
  begin
    newIndex := fMouseOverRow;

    if newIndex > fItems.Count - 1 then
    begin
      //Double clicking not allowed if we are clicking past the end of the list, but keep last item selected
      fTimeOfLastClick := 0;
      newIndex := fItems.Count - 1;
    end;

    if newIndex <> fItemIndex then
    begin
      fItemIndex := newIndex;
      fTimeOfLastClick := 0; //Double click shouldn't happen if you click on one server A, then server B
      if Assigned(fOnChange) then
        fOnChange(Self);
    end;
  end;
end;


function TKMListBox.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMListBox.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  inherited;

  if aHandled then Exit;

  SetTopIndex(TopIndex - WheelSteps);
  fScrollBar.Position := TopIndex; //Make the scrollbar move too when using the wheel

  aHandled := WheelSteps <> 0;
end;


procedure TKMListBox.Paint;
var
  I: Integer;
  shapeColor, outlineColor: TColor4;
begin
  inherited;

  // Draw background
  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, PaintWidth, Height, 1, fBackAlpha);

  // Draw selection outline and rectangle (shape)
  if (fItemIndex <> -1) and InRange(fItemIndex - TopIndex, 0, GetVisibleRows - 1) then
  begin
    if IsFocused then
    begin
      shapeColor := clListSelShape;
      outlineColor := clListSelOutline;
    end else begin
      shapeColor := clListSelShapeUnfocused;
      outlineColor := clListSelOutlineUnfocused;
    end;
    TKMRenderUI.WriteShape(AbsLeft, AbsTop + GetItemTop(fItemIndex) - GetItemTop(TopIndex),
                           PaintWidth, fItemHeight, shapeColor, outlineColor);
  end;

  // Draw text lines
  for I := 0 to Min(fItems.Count, GetVisibleRows) - 1 do
    TKMRenderUI.WriteText(AbsLeft + TXT_PAD_X, AbsTop + GetItemTop(I) + TXT_PAD_Y, RenderTextWidth, fItems.Strings[TopIndex+I] , fFont, taLeft);

  // Draw separators
  for I := 0 to Length(fSeparatorPositions) - 1 do
  begin
    TKMRenderUI.WriteShape(AbsLeft, AbsTop + GetItemTop(fSeparatorPositions[I]) - fSeparatorHeight,
                           PaintWidth - 1, fSeparatorHeight, fSeparatorColor);
    if fSeparatorTexts[I] <> '' then
      TKMRenderUI.WriteText(AbsLeft + TXT_PAD_X, AbsTop + GetItemTop(fSeparatorPositions[I]) - fSeparatorHeight,
                            RenderTextWidth, fSeparatorTexts[I], fSeparatorFont, taCenter)
  end;
end;


{ TKMListHeader }
constructor TKMListHeader.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  BackAlpha := 0.5;
  EdgeAlpha := 0.75;
  fSortDirection := sdNone;
  fSortIndex := -1;
end;


destructor TKMListHeader.Destroy;
begin
  ClearColumns;

  inherited;
end;


procedure TKMListHeader.ClearColumns;
var
  I: Integer;
begin
  for I := 0 to fCount - 1 do
    FreeAndNil(fColumns[I]);
end;


function TKMListHeader.GetColumnIndex(X: Integer): Integer;
var
  I, cellRightOffset: Integer;
begin
  Result := -1;

  for I := 0 to fCount - 1 do
  begin
    if I = fCount - 1 then
      cellRightOffset := AbsLeft + Width
    else
      cellRightOffset := AbsLeft + fColumns[I+1].Offset - 1;
    if InRange(X, AbsLeft + fColumns[I].Offset, cellRightOffset) then
      Result := I;
  end;
end;


function TKMListHeader.GetColumn(aIndex: Integer): TKMListHeaderColumn;
begin
  Result := fColumns[aIndex];
end;


function TKMListHeader.GetColumnWidth(aIndex: Integer): Integer;
begin
  if aIndex = fCount - 1 then
    Result := Width - fColumns[aIndex].Offset
  else
    Result := fColumns[aIndex+1].Offset - fColumns[aIndex].Offset;
end;


function TKMListHeader.GetHint: UnicodeString;
begin
  Result := inherited GetHint;
  if (Result = '') and (fColumnHighlight <> -1) then
    Result := HeaderHint[fColumnHighlight];
end;


//We know we were clicked and now we can decide what to do
procedure TKMListHeader.DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  columnID: Integer;
begin
  //do not invoke inherited here, to fully override parent DoClick method
  columnID := GetColumnIndex(X);
  if (columnID <> -1) and Assigned(OnColumnClick) then
  begin
    //We could process the clicks here (i.e. do the sorting inplace)
    //but there are various circumstances where plain string sorting will look wrong
    //and the ListBox just misses the knowledge to do it right:
    //MP game status (sort by type), ping (sort 1>9), playercount (sort 9>1), dates (sort by TDateTime)
    //Let the UI communicate to Game and do it right

    //Apply sorting to the column, toggling the state, sdDown is default
    if fSortIndex = columnID then
      if fSortDirection = sdDown then
        fSortDirection := sdUp
      else
        fSortDirection := sdDown
    else
      fSortDirection := sdDown;
    fSortIndex := columnID;
    OnColumnClick(columnID);
  end
  else
    inherited; //Process the usual clicks if e.g. there are no columns
end;


procedure TKMListHeader.SetColumns(aFont: TKMFont; aColumns: array of String; aColumnOffsets: array of Word);
var
  hints: array of String;
begin
  SetLength(hints, Length(aColumns));
  SetColumns(aFont, aColumns, hints, aColumnOffsets);
end;


procedure TKMListHeader.SetColumns(aFont: TKMFont; aColumns, aHints: array of String; aColumnOffsets: array of Word);
var
  I: Integer;
begin
  Assert(Length(aColumns) = Length(aColumnOffsets));
  Assert(Length(aHints) = Length(aColumnOffsets));

  fFont := aFont;

  ClearColumns;

  fCount := Length(aColumns);
  SetLength(fColumns, fCount);
  for I := 0 to fCount - 1 do
  begin
    fColumns[I] := TKMListHeaderColumn.Create;
    fColumns[I].Caption := aColumns[I];
    fColumns[I].HeaderHint := aHints[I];
    fColumns[I].Offset := aColumnOffsets[I];
  end;
end;


function TKMListHeader.GetOffset(aIndex: Integer): Word;
begin
  Result := fColumns[aIndex].Offset;
end;


procedure TKMListHeader.SetOffset(aIndex: Integer; aValue: Word);
begin
  fColumns[aIndex].Offset := aValue;
end;


function TKMListHeader.GetHeaderHint(aIndex: Integer): UnicodeString;
begin
  Result := fColumns[aIndex].HeaderHint;
end;


procedure TKMListHeader.SetHeaderHint(aIndex: Integer; const aValue: UnicodeString);
begin
  fColumns[aIndex].HeaderHint := aValue;
end;


procedure TKMListHeader.MouseMove(X, Y: Integer; Shift: TShiftState);
begin
  inherited;
  fColumnHighlight := GetColumnIndex(X);
end;


procedure TKMListHeader.Paint;
var
  I: Integer;
  columnLeft: Integer;
  columnWidth: Integer;
  textSize: TKMPoint;
begin
  inherited;

  for I := 0 to fCount - 1 do
  begin
    if I < fCount - 1 then
      columnWidth := fColumns[I+1].Offset - fColumns[I].Offset
    else
      columnWidth := Width - fColumns[I].Offset;

    if columnWidth <= 0 then Break;

    columnLeft := AbsLeft + fColumns[I].Offset;

    TKMRenderUI.WriteBevel(columnLeft, AbsTop, columnWidth, Height, EdgeAlpha, BackAlpha);
    if Assigned(OnColumnClick) and (csOver in State) and (fColumnHighlight = I) then
      TKMRenderUI.WriteShape(columnLeft, AbsTop, columnWidth, Height, $20FFFFFF);

    if fColumns[I].Glyph.ID <> 0 then
      TKMRenderUI.WritePicture(columnLeft + 4, AbsTop, columnWidth - 8, Height, [], fColumns[I].Glyph.RX, fColumns[I].Glyph.ID)
    else
    begin
      textSize := gRes.Fonts[fFont].GetTextSize(fColumns[I].Caption);
      TKMRenderUI.WriteText(columnLeft + 4, AbsTop + (Height - textSize.Y) div 2 + 2, columnWidth - 8, fColumns[I].Caption, fFont, fTextAlign);
    end;

    if Assigned(OnColumnClick) and (fSortIndex = I) then
      case fSortDirection of
        sdDown: TKMRenderUI.WritePicture(columnLeft + columnWidth - 4-10, AbsTop + 6, 10, 11, [], rxGui, 60);
        sdUp:   TKMRenderUI.WritePicture(columnLeft + columnWidth - 4-10, AbsTop + 6, 10, 11, [], rxGui, 59);
      end;
  end;
end;


{ TKMSearchableList }
procedure TKMSearchableList.KeyPress(Key: Char);
var
  I, oldIndex: Integer;
begin
  //KeyPress used only for key input search, do not allow unsupported Keys.
  //Otherwise fOnChange will be invoked on any key pressed
  if not IsCharAllowed(Key, acFileName) then Exit;

  if not CanSearch then
    Exit;

  oldIndex := GetItemIndex;

  //Allow to type several characters in a row to pick some item
  if TimeSince(fLastKeyTime) < 1000 then
    fSearch := fSearch + Key
  else
    fSearch := Key;

  fLastKeyTime := TimeGet;

  for I := 0 to GetRowCount - 1 do
    if AnsiStartsText(fSearch, GetItemString(I)) then
    begin
      SetItemIndex(I);
      SetTopIndex(GetItemIndex - GetVisibleRows div 2);
      Break;
    end;

  if Assigned(fOnChange) and (oldIndex <> GetItemIndex) then
    fOnChange(Self);
end;


function TKMSearchableList.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  //We want these keys to be ignored
  if Key in [VK_F1..VK_F12, VK_ESCAPE, VK_RETURN, VK_DELETE, VK_TAB] then
    Result := False
  else
    Result := CanSearch or (Key in [VK_UP, VK_DOWN, VK_HOME, VK_END, VK_PRIOR, VK_NEXT]);

  Result := Result and CanChangeSelection; //Don't handle keys if can't change selection
end;


function TKMSearchableList.CanChangeSelection: Boolean;
begin
  Result := True;
end;


function TKMSearchableList.GetHintFont: TKMFont;
begin
  Result := fFont;
end;


function TKMSearchableList.GetHintKind: TKMHintKind;
begin
  Result := hkTextNotFit;
end;


function TKMSearchableList.IsHintSelected: Boolean;
begin
  Result := (ItemIndex <> -1) and (GetMouseOverRow = ItemIndex);
end;


function TKMSearchableList.KeyDown(Key: Word; Shift: TShiftState): Boolean;
var
  oldIndex, newIndex: Integer;
  pageScrolling: Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyDown(Key, Shift) then Exit;

  if not CanChangeSelection then Exit; //Can't change selection

  pageScrolling := False;
  oldIndex := ItemIndex;
  case Key of
    VK_UP:      newIndex := ItemIndex - 1;
    VK_DOWN:    newIndex := ItemIndex + 1;
    VK_HOME:    newIndex := 0;
    VK_END:     newIndex := RowCount - 1;
    VK_PRIOR:   begin
                  newIndex := EnsureRange(ItemIndex - GetVisibleRows, 0, RowCount - 1);
                  pageScrolling := True;
                end;
    VK_NEXT:    begin
                  newIndex := EnsureRange(ItemIndex + GetVisibleRows, 0, RowCount - 1);
                  pageScrolling := True;
                end;
    VK_RETURN:  begin
                  //Trigger click to hide drop downs
                  if Assigned(fOnClick) then
                    fOnClick(Self);
                  //Double click on Enter
                  if Assigned(fOnDoubleClick) then
                    fOnDoubleClick(Self);
                  Exit;
                end;
    else        Exit;
  end;

  if InRange(newIndex, 0, RowCount - 1) then
  begin
    ItemIndex := newIndex;
    if pageScrolling then
      TopIndex := ItemIndex - (oldIndex - TopIndex) // Save position from the top of the list
    else if TopIndex < ItemIndex - GetVisibleRows + 1 then //Moving down
      TopIndex := ItemIndex - GetVisibleRows + 1
    else if TopIndex > ItemIndex then //Moving up
      TopIndex := ItemIndex;
  end;

  if Assigned(fOnChange) and (oldIndex <> newIndex) then
    fOnChange(Self);
end;


function TKMSearchableList.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyUp(Key, Shift) then Exit;
end;


procedure TKMSearchableList.SetTopIndex(aIndex: Integer; aStayOnList: Boolean);
begin
  if not aStayOnList
    or not InRange(aIndex - TopIndex, 0, GetVisibleRows - 1) then
  begin
    if aIndex < TopIndex then
      TopIndex := ItemIndex
    else
    if aIndex > TopIndex + GetVisibleRows - 1 then
      TopIndex := aIndex - GetVisibleRows + 1;
  end;
end;


{ TKMColumnListBox }
constructor TKMColumnBox.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle);
const
  DEF_HEADER_HEIGHT = 24;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont       := aFont;
  fItemHeight := 20;
  fItemIndex  := -1;
  fShowHeader := True;
  fShowHintWhenShort := False;
  SearchColumn := -1; //Disabled by default
  Focusable := True; //For up/down keys
  ColumnIdForScroll := -1;

  fHeader := TKMListHeader.Create(aParent, aLeft, aTop, aWidth - fItemHeight, DEF_HEADER_HEIGHT);

  fScrollBar := TKMScrollBar.Create(aParent, aLeft+aWidth-fItemHeight, aTop, fItemHeight, aHeight, saVertical, aStyle);
  UpdateScrollBar; //Initialise the scrollbar

  SetEdgeAlpha(1);
  SetBackAlpha(0.5);
end;


destructor TKMColumnBox.Destroy;
begin
  ClearColumns;

  inherited;
end;


function TKMColumnBox.CanSearch: Boolean;
begin
  Result := SearchColumn <> -1;
end;


function TKMColumnBox.GetRowCount: Integer;
begin
  Result := fRowCount;
end;


function TKMColumnBox.GetItemIndex: Integer;
begin
  Result := fItemIndex;
end;


function TKMColumnBox.GetItemString(aIndex: Integer): UnicodeString;
begin
  Result := Rows[aIndex].Cells[SearchColumn].Caption;
end;


function TKMColumnBox.GetMouseOverRow: Integer;
begin
  Result := fMouseOverRow;
end;


procedure TKMColumnBox.SetSearchColumn(aValue: ShortInt);
begin
  fSearchColumn := aValue;
end;


procedure TKMColumnBox.SetShowHeader(aValue: Boolean);
begin
  fHeader.Visible := aValue;
  fShowHeader := aValue;
end;


procedure TKMColumnBox.SetLeft(aValue: Integer);
begin
  inherited;

  fHeader.Left := Left;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
end;


procedure TKMColumnBox.SetTop(aValue: Integer);
begin
  inherited;

  //Update header and scrollbar so that their Top matched
  fHeader.Top := Top;
  fScrollBar.Top := Top;
end;


procedure TKMColumnBox.SetWidth(aValue: Integer);
begin
  inherited;

  fHeader.Width := Width;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
end;


procedure TKMColumnBox.SetHeight(aValue: Integer);
begin
  inherited;
  fScrollBar.Height := fHeight;
  UpdateScrollBar; //Since height has changed
end;


procedure TKMColumnBox.SetItemIndex(aIndex: Integer);
begin
  if InRange(aIndex, 0, RowCount - 1) then
    fItemIndex := aIndex
  else
    fItemIndex := -1;
end;


procedure TKMColumnBox.SetOnColumnClick(const Value: TIntegerEvent);
begin
  fHeader.OnColumnClick := Value;
end;


procedure TKMColumnBox.SetSortDirection(aDirection: TSortDirection);
begin
  fHeader.SortDirection := aDirection;
end;


procedure TKMColumnBox.SetSortIndex(aIndex: Integer);
begin
  fHeader.SortIndex := aIndex;
end;


//Copy property to scrollbar. Otherwise it won't be rendered
procedure TKMColumnBox.SetVisible(aValue: Boolean);
begin
  inherited;
  fHeader.Visible := fVisible and fShowHeader;
  fScrollBar.Visible := fVisible and fScrollBar.Enabled; //Hide scrollbar and its buttons
end;


function TKMColumnBox.GetSelfAbsTop: Integer;
begin
  Result := AbsTop + (fHeader.Height + 1) * Byte(fShowHeader);
end;


function TKMColumnBox.GetSelfHeight: Integer;
begin
  Result := Height - (fHeader.Height + 1) * Byte(fShowHeader);
end;


function TKMColumnBox.GetSelfWidth: Integer;
begin
  if fScrollBar.Visible then
    Result := Width - fScrollBar.Width //Leave space for scrollbar
  else
    Result := Width; //List takes up the entire width
end;


function TKMColumnBox.GetTopIndex: Integer;
begin
  Result := fScrollBar.Position;
end;


function TKMColumnBox.GetVisibleRows: Integer;
begin
  Result := Floor(GetVisibleRowsExact);
end;


function TKMColumnBox.GetVisibleRowsExact: Single;
begin
  Result := (fHeight - fHeader.Height * Byte(fShowHeader)) / fItemHeight;
end;


function TKMColumnBox.IsSelected: Boolean;
begin
  Result := fItemIndex <> -1;
end;


procedure TKMColumnBox.SetTopIndex(aIndex: Integer);
begin
  fScrollBar.Position := aIndex;
end;


procedure TKMColumnBox.SetBackAlpha(aValue: Single);
begin
  fBackAlpha := aValue;
  fHeader.BackAlpha := aValue;
  fScrollBar.BackAlpha := aValue;
end;


procedure TKMColumnBox.SetEdgeAlpha(aValue: Single);
begin
  fEdgeAlpha := aValue;
  fHeader.EdgeAlpha := aValue;
  fScrollBar.EdgeAlpha := aValue;
end;


procedure TKMColumnBox.SetEnabled(aValue: Boolean);
begin
  inherited;
  fHeader.Enabled := fEnabled;
  fScrollBar.Enabled := fEnabled;
end;


function TKMColumnBox.GetColumn(aIndex: Integer): TKMListColumn;
begin
  Result := fColumns[aIndex];
end;


function TKMColumnBox.GetItem(aIndex: Integer): TKMListRow;
begin
  if InRange(aIndex, 0, RowCount - 1) then
    Result := Rows[aIndex]
  else
    raise Exception.Create('Cannot get Item with index ' + IntToStr(aIndex));
end;


function TKMColumnBox.GetSelectedItem: TKMListRow;
begin
  if IsSelected then
    Result := Rows[fItemIndex]
  else
    raise Exception.Create('No selected item found');
end;


function TKMColumnBox.GetSelectedItemTag: Integer;
begin
  Result := -1;
  if IsSelected then
    Result := GetSelectedItem.Tag;
end;


procedure TKMColumnBox.ScrollBarChangeVisibility;
var
  I: Integer;
begin
  if Visible and (ColumnIdForScroll <> -1) then
  begin
    if fScrollBar.Visible then
      for I := ColumnIdForScroll to fHeader.Count - 1 do
        fHeader.Offset[I] := fHeader.Offset[I] - fScrollBar.Width
    else
    begin
      for I := ColumnIdForScroll to fHeader.Count - 1 do
        fHeader.Offset[I] := fHeader.Offset[I] + fScrollBar.Width;
    end;
  end;
end;


function TKMColumnBox.GetOnColumnClick: TIntegerEvent;
begin
  Result := fHeader.OnColumnClick;
end;


function TKMColumnBox.GetSortDirection: TSortDirection;
begin
  Result := fHeader.SortDirection;
end;


function TKMColumnBox.GetSortIndex: Integer;
begin
  Result := fHeader.SortIndex;
end;


//fRowCount or Height has changed
procedure TKMColumnBox.UpdateScrollBar;
var
  oldScrollBarVisible: Boolean;
begin
  fScrollBar.MaxValue := fRowCount - (fHeight - fHeader.Height * Byte(fShowHeader)) div fItemHeight;
  Assert(fScrollBar.MaxValue >= fScrollBar.MinValue);
  oldScrollBarVisible := fScrollBar.Visible;
  fScrollBar.Visible := fVisible and (fScrollBar.MaxValue <> fScrollBar.MinValue);
  if fScrollBar.Visible <> oldScrollBarVisible then
    ScrollBarChangeVisibility;

end;


//If we don't add columns there will be Assert on items add
procedure TKMColumnBox.SetColumns(aHeaderFont: TKMFont; aCaptions: array of string; aOffsets: array of Word);
var
  hints: array of string;
begin
  SetLength(hints, Length(aCaptions));
  SetColumns(aHeaderFont, aCaptions, hints, aOffsets);
end;


procedure TKMColumnBox.SetColumns(aHeaderFont: TKMFont; aCaptions: array of string; aOffsets: array of Word; aCaptionsAsHints: Boolean);
begin
  if aCaptionsAsHints then
    SetColumns(aHeaderFont, aCaptions, aCaptions, aOffsets)
  else
    SetColumns(aHeaderFont, aCaptions, aOffsets);
end;


procedure TKMColumnBox.SetColumns(aHeaderFont: TKMFont; aCaptions, aHints: array of String; aOffsets: array of Word);
var
  I: Integer;
begin
  Assert(Length(aCaptions) = Length(aOffsets));
  Assert(Length(aHints) = Length(aOffsets));

  Clear; //We don't want to conflict with already added rows elements
  ClearColumns;

  fHeader.SetColumns(aHeaderFont, aCaptions, aHints, aOffsets);

  SetLength(fColumns, fHeader.ColumnCount);
  for I := 0 to fHeader.ColumnCount - 1 do
  begin
    fColumns[I] := TKMListColumn.Create;
    fColumns[I].Font := fFont; //Reset to default font
    fColumns[I].TextAlign := taLeft; //Default alignment
    fColumns[I].TriggerOnChange := True; //by default all columns trigger OnChange
  end;
end;


procedure TKMColumnBox.AddItem(aItem: TKMListRow);
begin
  Assert(fHeader.ColumnCount > 0);
  Assert(Length(aItem.Cells) = fHeader.ColumnCount);

  if fRowCount >= Length(Rows) then
    SetLength(Rows, fRowCount + 16);

  Rows[fRowCount] := aItem;

  Inc(fRowCount);
  UpdateScrollBar;
end;


procedure TKMColumnBox.Clear;
begin
  fRowCount := 0;
  fItemIndex := -1;
  UpdateScrollBar;
end;


procedure TKMColumnBox.ClearColumns;
var
  I: Integer;
begin
  for I := 0 to fHeader.ColumnCount - 1 do
    FreeAndNil(fColumns[I]);
end;


procedure TKMColumnBox.JumpToSelected;
begin
  if (ItemIndex <> -1)
    and not InRange(ItemIndex - TopIndex, 0, GetVisibleRows-1)
  then
    if ItemIndex < TopIndex then
      TopIndex := ItemIndex
    else
    if ItemIndex > TopIndex + GetVisibleRows - 1 then
      TopIndex := ItemIndex - GetVisibleRows + 1;
end;


function TKMColumnBox.KeyDown(Key: Word; Shift: TShiftState): Boolean;
begin
  if PassAllKeys then Exit(False);

  Result := inherited;
end;


function TKMColumnBox.CanChangeSelection: Boolean;
begin
  Result := not HideSelection;
end;


function TKMColumnBox.CanFocusNext: Boolean;
begin
  Result := not PassAllKeys;
end;


procedure TKMColumnBox.KeyPress(Key: Char);
begin
  if PassAllKeys then
    Exit
  else
    inherited;
end;


function TKMColumnBox.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
  if PassAllKeys then
  begin
    if Assigned(fOnKeyUp) then
      Result := fOnKeyUp(Self, Key, Shift);

    Exit;
  end;

  Result := inherited;
end;


//Update mouse over row/cell positions (fMouseOver* variables)
procedure TKMColumnBox.UpdateMouseOverPosition(X,Y: Integer);
var
  I, cellLeftOffset, cellRightOffset: Integer;
begin
  fMouseOverColumn := -1;
  fMouseOverRow := -1;
  fMouseOverCell := KMPOINT_INVALID_TILE;

  if InRange(X, AbsLeft, AbsLeft + Width - fScrollBar.Width * Byte(fScrollBar.Visible))
    and InRange(Y, AbsTop + fHeader.Height*Byte(fHeader.Visible), AbsTop + fHeader.Height*Byte(fHeader.Visible) + Floor(GetVisibleRowsExact * fItemHeight) - 1) then
  begin
    for I := 0 to fHeader.ColumnCount - 1 do
    begin
      cellLeftOffset := AbsLeft + fHeader.Columns[I].Offset;
      if I = fHeader.ColumnCount - 1 then
        cellRightOffset := AbsLeft + Width - fScrollBar.Width * Byte(fScrollBar.Visible)
      else
        cellRightOffset := AbsLeft + fHeader.Columns[I+1].Offset - 1;
      if InRange(X, cellLeftOffset, cellRightOffset) then
      begin
        fMouseOverColumn := I;
        Break;
      end;
    end;

    fMouseOverRow := TopIndex + (Y - AbsTop - fHeader.Height * Byte(fShowHeader)) div fItemHeight;

    if fMouseOverRow >= fRowCount then
      fMouseOverRow := -1;

    if (fMouseOverRow <> -1) and (fMouseOverColumn <> -1) then
      fMouseOverCell := KMPoint(fMouseOverColumn, fMouseOverRow);
  end;
end;


procedure TKMColumnBox.DoClick(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  isClickHandled: Boolean;
begin
  //do not invoke inherited here, to fully override parent DoClick method
  isClickHandled := False;

  if not KMSamePoint(fMouseOverCell, KMPOINT_INVALID_TILE)
    and Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Enabled then
  begin
    if Assigned(fOnCellClick) then
      isClickHandled := isClickHandled or fOnCellClick(Self, fMouseOverCell.X, fMouseOverCell.Y)
    else
      if Assigned(fOnCellClickShift) then
        isClickHandled := isClickHandled or fOnCellClickShift(Self, Shift, fMouseOverCell.X, fMouseOverCell.Y)
  end;

  //Let propagate click event only when OnCellClick did not handle it
  if not isClickHandled then
  begin
    inherited DoClick(X, Y, Shift, Button);
    if Assigned(fOnChange)
      and not fOnChangeInvoked
      and (fMouseOverCell <> KMPOINT_INVALID_TILE) //Only trigger ovew cells
      and Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Enabled then // Only trigger for enabled cells
      fOnChange(Self);
  end;
end;


procedure TKMColumnBox.UpdateItemIndex(Shift: TShiftState; var aOnChangeInvoked: Boolean);
var
  newIndex: Integer;
begin
  aOnChangeInvoked := False;
  if not (ssLeft in Shift) or (fMouseOverRow = -1) then
    Exit;

  // Do not do anything else, in case Cell we are working on is Disabled
  if (fMouseOverCell = KMPOINT_INVALID_TILE)
    or not Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Enabled then
    Exit;

  newIndex := fMouseOverRow;

  if newIndex >= fRowCount then
  begin
    //Double clicking not allowed if we are clicking past the end of the list, but keep last item selected
    fTimeOfLastClick := 0;
    newIndex := -1;
  end;

  if InRange(newIndex, 0, fRowCount - 1) and (newIndex <> fItemIndex)  then
  begin
    fTimeOfLastClick := 0; //Double click shouldn't happen if you click on one server A, then server B
    ItemIndex := newIndex;
    if not KMSamePoint(fMouseOverCell, KMPOINT_INVALID_TILE)
      and Columns[fMouseOverCell.X].TriggerOnChange
      and (fMouseOverCell <> KMPOINT_INVALID_TILE) //Only trigger ovew cells
      and Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Enabled // Only trigger for enabled cells
      and Assigned(fOnChange) then
    begin
      fOnChange(Self);
      aOnChangeInvoked := True;
    end;
  end;
end;


procedure TKMColumnBox.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  UpdateMouseOverPosition(X, Y);
  UpdateItemIndex(Shift, fOnChangeInvoked);
  //Lets do DoClick here instead of MouseUp event handler, because of some TKMColumnBox specific logic
  if (csDown in State) then
  begin
    State := State - [csDown];

    //Send Click events
    DoClick(X, Y, Shift, Button);
    fOnChangeInvoked := False;
  end;
end;


procedure TKMColumnBox.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  onChangeInvoked: Boolean;
begin
  inherited;
  UpdateMouseOverPosition(X, Y);
  UpdateItemIndex(Shift, onChangeInvoked);
end;


procedure TKMColumnBox.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //We handle normal MouseUp event in MouseDown, so just hide ancestor MouseUp here
end;


function TKMColumnBox.DoHandleMouseWheelByDefault: Boolean;
begin
  Result := False;
end;


procedure TKMColumnBox.MouseWheel(Sender: TObject; WheelSteps: Integer; var aHandled: Boolean);
begin
  inherited;

  if aHandled then Exit;

  SetTopIndex(TopIndex - WheelSteps);
  fScrollBar.Position := TopIndex; //Make the scrollbar move too when using the wheel

  aHandled := WheelSteps <> 0;
end;


function TKMColumnBox.GetHint: UnicodeString;
var
  hintStr: String;
begin
  Result := inherited GetHint;
  if Result = '' then
  begin
    if not KMSamePoint(fMouseOverCell, KMPOINT_INVALID_TILE)
      //Got crashed sometimes when mouse over empty disabled ComboBox with Header (fMouseOverCell = [0;0])
      and (Length(Rows) > fMouseOverCell.Y)
      and (Length(Rows[fMouseOverCell.Y].Cells) > fMouseOverCell.X) then
    begin
      Result := Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].CellHint;
      if fShowHintWhenShort and (Result = '') then
      begin
        hintStr := Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Caption;
        // Show hint, if caption does not fit into the cell
        if gRes.Fonts[fFont].GetTextSize(hintStr).X > fHeader.ColumnWidth[fMouseOverCell.X] - COL_PAD_X then
          Result := hintStr;
      end;
    end;
  end;
end;


function TKMColumnBox.GetHintTextColor: TColor4;
begin
  if fMouseOverCell = KMPOINT_INVALID_TILE then Exit(inherited);

  Result := Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Color;
end;


function TKMColumnBox.GetHintBackRect: TKMRect;
const
  SELECT_PAD = 1;
var
  top: Integer;
begin
  if fMouseOverCell = KMPOINT_INVALID_TILE then Exit(KMRECT_ZERO);

  top := fHeader.Height * Byte(fShowHeader) + (fMouseOverCell.Y - TopIndex) * fItemHeight - SELECT_PAD;
  Result := KMRect(fHeader.Columns[fMouseOverCell.X].Offset, //beware we dont consider hidden columns here, since there are none needed atm
                   top,
                   0, // Width is not used
                   top + fItemHeight + SELECT_PAD);
end;


function TKMColumnBox.GetHintTextOffset: TKMPoint;
var
  textSize: TKMPoint;
begin
  if fMouseOverCell = KMPOINT_INVALID_TILE then Exit(KMPOINT_ZERO);

  textSize := gRes.Fonts[fFont].GetTextSize(Rows[fMouseOverCell.Y].Cells[fMouseOverCell.X].Caption);

  Result := KMPoint(COL_PAD_X + fHeader.Columns[fMouseOverCell.X].Offset, //beware we dont consider hidden columns here, since there are none needed atm
                    TXT_PAD_Y + fHeader.Height * Byte(fShowHeader)
                              + (fMouseOverCell.Y - TopIndex) * fItemHeight
                              + (fItemHeight - textSize.Y) div 2);
end;


procedure TKMColumnBox.DoPaintLine(aIndex: Integer; X, Y: Integer; PaintWidth: Integer; aAllowHighlight: Boolean = True);
var
  I: Integer;
  columnsToShow: array of Boolean;
begin
  SetLength(columnsToShow, Length(fColumns));
  for I := Low(columnsToShow) to High(columnsToShow) do
    columnsToShow[I] := True; // show all columns by default
  DoPaintLine(aIndex, X, Y, PaintWidth, columnsToShow, aAllowHighlight);
end;


procedure TKMColumnBox.DoPaintLine(aIndex: Integer; X, Y: Integer; PaintWidth: Integer; aColumnsToShow: array of Boolean;
                                   aAllowHighlight: Boolean = True);
  function IsHighlightOverCell(aCellIndex: Integer): Boolean;
  begin
    Result := aAllowHighlight
                and Rows[aIndex].Cells[aCellIndex].HighlightOnMouseOver
                and (fMouseOverCell.X = aCellIndex) and (fMouseOverCell.Y = aIndex)
                and (csOver in State);
  end;

var
  I: Integer;
  availWidth, hiddenColumnsTotalWidth: Integer;
  textSize: TKMPoint;
  color: Cardinal;
begin
  Assert(Length(fColumns) = Length(aColumnsToShow));
  hiddenColumnsTotalWidth := 0;
  for I := 0 to fHeader.ColumnCount - 1 do
  begin
    if not aColumnsToShow[I] then
    begin
      Inc(hiddenColumnsTotalWidth, fHeader.ColumnWidth[I]);
      Continue;
    end;
    //Determine available width
    if I = fHeader.ColumnCount - 1 then
      availWidth := PaintWidth - 4 - fHeader.Columns[I].Offset - COL_PAD_X
    else
      availWidth := fHeader.Columns[I+1].Offset - fHeader.Columns[I].Offset - COL_PAD_X;
    //Trim the width based on our allowed PaintWidth
    availWidth := Min(availWidth, PaintWidth - fHeader.Columns[I].Offset);

    if availWidth <= 0 then Continue; //If the item overflows our allowed PaintWidth do not paint it

    //Paint column
    if Rows[aIndex].Cells[I].Pic.ID <> 0 then
      TKMRenderUI.WritePicture(X + COL_PAD_X + fHeader.Columns[I].Offset - hiddenColumnsTotalWidth, Y + 1,
                               availWidth, fItemHeight, [],
                               Rows[aIndex].Cells[I].Pic.RX,
                               Rows[aIndex].Cells[I].Pic.ID,
                               Rows[aIndex].Cells[I].Enabled,
                               Rows[aIndex].Cells[I].Color,
                               0.4*Byte(IsHighlightOverCell(I) or (HighlightOnMouseOver and (csOver in State) and (fMouseOverRow = aIndex))));

    if Rows[aIndex].Cells[I].Caption <> '' then
      if Rows[aIndex].Cells[I].SubTxt <> '' then
      begin
        textSize := gRes.Fonts[fFont].GetTextSize(Rows[aIndex].Cells[I].Caption);
        TKMRenderUI.WriteText(X + COL_PAD_X + fHeader.Offset[I] - hiddenColumnsTotalWidth,
                              Y + 4,
                              availWidth,
                              Rows[aIndex].Cells[I].Caption,
                              fColumns[I].Font, fColumns[I].TextAlign, Rows[aIndex].Cells[I].Color);
        TKMRenderUI.WriteText(X + COL_PAD_X + fHeader.Offset[I] - hiddenColumnsTotalWidth,
                              Y + 1 + fItemHeight div 2,
                              availWidth,
                              Rows[aIndex].Cells[I].SubTxt,
                              fColumns[I].HintFont, fColumns[I].TextAlign, $FFB0B0B0);
      end else
      begin
        textSize := gRes.Fonts[fFont].GetTextSize(Rows[aIndex].Cells[I].Caption);
        if aAllowHighlight
          and ((HighlightOnMouseOver and (csOver in State) and (fMouseOverRow = aIndex))
          or (HighlightError and (aIndex = ItemIndex))
          or IsHighlightOverCell(I)) then
          color := Rows[aIndex].Cells[I].HighlightColor
        else
          color := Rows[aIndex].Cells[I].Color;

        if not fEnabled then
          color := ReduceBrightness(color, 136);
        TKMRenderUI.WriteText(X + COL_PAD_X + fHeader.Offset[I] - hiddenColumnsTotalWidth,
                              Y + TXT_PAD_Y + (fItemHeight - textSize.Y) div 2,
                              availWidth,
                              Rows[aIndex].Cells[I].Caption,
                              fColumns[I].Font, fColumns[I].TextAlign, color);
      end;
  end;
end;


procedure TKMColumnBox.Paint;
var
  I, paintWidth, maxItem, Y: Integer;
  outlineColor, shapeColor: TColor4;
begin
  inherited;

  if fScrollBar.Visible then
    paintWidth := Width - fScrollBar.Width //Leave space for scrollbar
  else
    paintWidth := Width; //List takes up the entire width

  fHeader.Width := paintWidth;

  Y := AbsTop + fHeader.Height * Byte(fShowHeader);
  maxItem := GetVisibleRows;

  TKMRenderUI.WriteBevel(AbsLeft, Y, paintWidth, Height - fHeader.Height * Byte(fShowHeader), fEdgeAlpha, fBackAlpha);

  //Grid lines should be below selection focus
  if fShowLines then
    for I := 0 to Math.Min(fRowCount, maxItem) do
      TKMRenderUI.WriteShape(AbsLeft+1, Y + I * fItemHeight - 1, paintWidth - 2, 1, $FFBBBBBB);

  TKMRenderUI.SetupClipY(AbsTop, AbsTop + Height - 1);

  //Selection highlight
  if not HideSelection
    and (fItemIndex <> -1)
    and InRange(ItemIndex - TopIndex, 0, maxItem) then
  begin

    if IsFocused then
    begin
      shapeColor := clListSelShape;
      outlineColor := clListSelOutline;
    end else begin
      shapeColor := clListSelShapeUnfocused;
      outlineColor := clListSelOutlineUnfocused;
    end;

    TKMRenderUI.WriteShape(AbsLeft, Y + fItemHeight * (fItemIndex - TopIndex), paintWidth, fItemHeight, shapeColor);
    TKMRenderUI.WriteOutline(AbsLeft, Y + fItemHeight * (fItemIndex - TopIndex), paintWidth, fItemHeight, 1 + Byte(fShowLines), outlineColor);
  end;

  //Paint rows text and icons above selection for clear visibility
  for I := 0 to Math.min(fRowCount - TopIndex - 1, maxItem) do
    DoPaintLine(TopIndex + I, AbsLeft, Y + I * fItemHeight, paintWidth);

  TKMRenderUI.ReleaseClipY;
end;


{ TKMPopUpMenu }
constructor TKMPopUpMenu.Create(aParent: TKMPanel; aWidth: Integer);
begin
  inherited Create(aParent, 0, 0, aWidth, 0);

  fShapeBG := TKMShape.Create(Self, 0, 0, aParent.Width, aParent.Height);
  fShapeBG.AnchorsStretch;
  fShapeBG.OnClick := MenuHide;
  fShapeBG.Hide;

  fList := TKMColumnBox.Create(Self, 0, 0, aWidth, 0, fntGrey, bsMenu);
  fList.AnchorsStretch;
  fList.BackAlpha := 0.8;
  fList.Focusable := False;
  fList.SetColumns(fntGrey, [''], [0]);
  fList.ShowHeader := False;
  fList.OnClick := MenuClick;
  fList.Hide;

  Hide;
end;


procedure TKMPopUpMenu.Clear;
begin
  fList.Clear;
end;


function TKMPopUpMenu.GetItemIndex: Integer;
begin
  Result := fList.ItemIndex;
end;


function TKMPopUpMenu.GetItemTag(aIndex: Integer): Integer;
begin
  Result := fList.Rows[aIndex].Tag;
end;


procedure TKMPopUpMenu.SetItemIndex(aValue: Integer);
begin
  fList.ItemIndex := aValue;
end;


procedure TKMPopUpMenu.AddItem(const aCaption: UnicodeString; aTag: Integer = 0);
begin
  fList.AddItem(MakeListRow([aCaption], aTag));
  Height := fList.ItemHeight * fList.RowCount;
end;


procedure TKMPopUpMenu.UpdateItem(aIndex: Integer; const aCaption: UnicodeString);
begin
  fList.Rows[aIndex].Cells[0].Caption := aCaption;
end;


procedure TKMPopUpMenu.MenuClick(Sender: TObject);
begin
  if Assigned(fOnClick) then
    fOnClick(Self);

  MenuHide(Self);
end;


procedure TKMPopUpMenu.MenuHide(Sender: TObject);
begin
  Hide;
  fList.Hide;
  fShapeBG.Hide;
end;


procedure TKMPopUpMenu.HideMenu;
begin
  MenuHide(nil);
end;


procedure TKMPopUpMenu.ShowAt(X, Y: Integer);
begin
  fList.AbsLeft := X;
  fList.AbsTop := Y;

  //Reset previously selected item
  fList.ItemIndex := -1;

  Show;
  fShapeBG.Show;
  fList.Show;
end;


{ TKMPopUpPanel }
// aWidth / aHeight represents not TKMPopUpPanel sizes, but its internal panel: ItemsPanel
// PopUpPanel draw bigger image behind it
constructor TKMPopUpPanel.Create(aParent: TKMPanel; aWidth, aHeight: Integer; const aCaption: UnicodeString = '';
                                 aImageType: TKMPopUpBGImageType = pubgitYellow; aWithCrossImg: Boolean = False;
                                 aShowBevel: Boolean = True; aShowShadeBevel: Boolean = True);
var
  margin, l, t, topMarg, baseW, baseH, w, h: Integer;
begin
  fBGImageType := aImageType;

  margin := GetLeftRightMargin;

  baseW := aWidth + 2*margin;
  topMarg := GetTopMargin;
  baseH := aHeight + GetBottomMargin + topMarg;
  w := Min(aParent.Width, baseW);
  h := Min(aParent.Height, baseH);
  l := Max(0, (aParent.Width - w) div 2);
  t := Max(0, (aParent.Height - h) div 2);

  // Create panel with calculated sizes
  inherited Create(aParent, l, t, w, h);

  // Fix its base sizes as a desired one
  BaseWidth := baseW;
  BaseHeight := baseH;

  FitInParent := True;
  Font := DEF_FONT;
  FontColor := icWhite;
  Caption := aCaption;
  DragEnabled := False;

  if aShowShadeBevel then
    BevelShade := TKMBevel.Create(Self, -2000,  -2000, 5000, 5000);

  ImageBG := TKMImage.Create(Self, 0, 0, w, h, 15, rxGuiMain);

  ItemsPanel := TKMPanel.Create(Self, margin, topMarg, Width - 2*margin, Height - topMarg - GetBottomMargin);

  case fBGImageType of
    pubgitGray:   ImageBG.TexId := 15;
    pubgitYellow: ImageBG.TexId := 18;
    pubgitScroll: begin
                    ImageBG.Rx := rxGui;
                    ImageBG.TexId := 409;
                  end;
  end;

  if aWithCrossImg then
  begin
    ImageClose := TKMImage.Create(Self, Width - GetCrossRight, GetCrossTop, 31, 30, 52);
    ImageClose.Anchors := [anTop, anRight];
    ImageClose.Hint := gResTexts[TX_MSG_CLOSE_HINT];
    ImageClose.OnClick := Close;
    ImageClose.HighlightOnMouseOver := True;
  end;

  ItemsPanel.AnchorsStretch;
  if aShowBevel then
  begin
    BevelBG := TKMBevel.Create(ItemsPanel, 0, 0, ItemsPanel.Width, ItemsPanel.Height);
    BevelBG.AnchorsStretch;
  end;

  ImageBG.ImageStretch;

  AnchorsCenter;
  Hide;

  // Subscribe to get other controls mouse move events
  fMasterControl.AddMouseMoveCtrlSub(ControlMouseMove);

  // Subscribe to get other controls mouse down events
  fMasterControl.AddMouseDownCtrlSub(ControlMouseDown);

    // Subscribe to get other controls mouse up events
  fMasterControl.AddMouseUpCtrlSub(ControlMouseUp);
end;


function TKMPopUpPanel.GetLeftRightMargin: Integer;
begin
  Result := 0;
  case fBGImageType of
    pubgitGray:   Result := 20;
    pubgitYellow: Result := 35;
    pubgitScroll: Result := 20;
  end;
end;


function TKMPopUpPanel.GetTopMargin: Integer;
begin
  Result := 0;
  case fBGImageType of
    pubgitGray:   Result := 40;
    pubgitYellow: Result := 80;
    pubgitScroll: Result := 50;
  end;
end;


function TKMPopUpPanel.GetBottomMargin: Integer;
begin
  Result := 0;
  case fBGImageType of
    pubgitGray:   Result := 20;
    pubgitYellow: Result := 50;
    pubgitScroll: Result := 20;
  end;
end;


function TKMPopUpPanel.GetCrossTop: Integer;
begin
  Result := 0;
  case fBGImageType of
    pubgitGray:   Result := 24;
    pubgitYellow: Result := 40;
    pubgitScroll: Result := 24;
  end;
end;


function TKMPopUpPanel.GetCrossRight: Integer;
begin
  Result := 0;
  // We probably should calc those sizes as dependant of the Width
  case fBGImageType of
    pubgitGray:   Result := 50;
    pubgitYellow: Result := 130;
    pubgitScroll: Result := 55;
  end;
end;


procedure TKMPopUpPanel.Close(Sender: TObject);
begin
  Hide;

  if Assigned(fOnClose) then
    fOnClose;
end;


procedure TKMPopUpPanel.ControlMouseDown(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if Sender = ImageBG then
    MouseDown(X, Y, Shift, Button);
end;


procedure TKMPopUpPanel.ControlMouseMove(Sender: TObject; X, Y: Integer; Shift: TShiftState);
begin
  inherited;

  MouseMove(X, Y, Shift);
end;


procedure TKMPopUpPanel.ControlMouseUp(Sender: TObject; X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  MouseUp(X, Y, Shift, Button);
end;


procedure TKMPopUpPanel.MouseDown(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  if not DragEnabled then Exit;

  fDragging := True;
  fDragStartPos := TKMPoint.New(X,Y);
end;

procedure TKMPopUpPanel.MouseMove(X, Y: Integer; Shift: TShiftState);
begin
  inherited;

  if not DragEnabled or not fDragging then Exit;

  Left := EnsureRange(Left + X - fDragStartPos.X, 0, fMasterControl.fMasterPanel.Width - Width);
  Top := EnsureRange(Top + Y - fDragStartPos.Y, -ImageBG.Top, fMasterControl.fMasterPanel.Height - Height);

  fDragStartPos := TKMPoint.New(X,Y);
end;

procedure TKMPopUpPanel.MouseUp(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  if not DragEnabled then Exit;

  fDragging := False;
end;


procedure TKMPopUpPanel.PaintPanel(aPaintLayer: Integer);
begin
  inherited;

  TKMRenderUI.WriteText(AbsLeft, AbsTop + GetTopMargin - 25 + CapOffsetY, Width, Caption, Font, taCenter, FontColor);
end;


procedure TKMPopUpPanel.SetHeight(aValue: Integer);
begin
  inherited;

  UpdateSizes;
end;


procedure TKMPopUpPanel.SetWidth(aValue: Integer);
begin
  inherited;

  UpdateSizes;
end;


procedure TKMPopUpPanel.UpdateSizes;
begin
  ImageBG.Width := Width;
  ImageBG.Height := Height;
end;


function TKMPopUpPanel.GetActualWidth: Integer;
begin
  Result := ItemsPanel.Width;
end;


procedure TKMPopUpPanel.SetActualWidth(aValue: Integer);
var
  baseW: Integer;
begin
  baseW := aValue + GetLeftRightMargin*2;
  SetWidth(Min(Parent.Width, baseW));
end;


function TKMPopUpPanel.GetActualHeight: Integer;
begin
  Result := ItemsPanel.Height;
end;


procedure TKMPopUpPanel.SetActualHeight(aValue: Integer);
var
  baseH, h: Integer;
begin
  baseH := aValue + GetBottomMargin + GetTopMargin;
  h := Min(Parent.Height, baseH);
  SetHeight(h);
end;


{ TKMDropCommon }
constructor TKMDropCommon.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont;
                                 aStyle: TKMButtonStyle; aAutoClose: Boolean = True; aPaintLayer: Integer = 0);
var
  P: TKMPanel;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aPaintLayer);

  fDropCount := 10;
  fDropUp := False;
  fFont := aFont;

  fButton := TKMButton.Create(aParent, aLeft+aWidth-aHeight, aTop, aHeight, aHeight, 590, rxGui, aStyle, aPaintLayer);
  fButton.OnClick := ButtonClick;
  fButton.MakesSound := False;

  P := MasterParent;
  fShape := TKMShape.Create(P, 0, 0, P.Width, P.Height, aPaintLayer);
  fShape.AnchorsStretch;
  fShape.fOnClick := ListHide;

  fAutoClose := aAutoClose;
end;


procedure TKMDropCommon.UpdateVisibility;
begin
  inherited;
  if not Visible then
    CloseList;
end;


function TKMDropCommon.IsOpen: Boolean;
begin
  Result := fShape.Visible;
end;


procedure TKMDropCommon.ButtonClick(Sender: TObject);
begin
  //Call the DoDlick event to show the list AND generate DropBox.OnClick event
  DoClick(fButton.AbsLeft + fButton.Width div 2, fButton.AbsTop + fButton.Height div 2, [], mbLeft);
end;


procedure TKMDropCommon.ListShow(Sender: TObject);
begin
  if ListVisible then
  begin
    ListHide(nil);
    Exit;
  end;

  if fAutoClose and (Count > 0) then
    fShape.Show;

  if Assigned(fOnShowList) then fOnShowList(Self);
end;


procedure TKMDropCommon.DoClick(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //do not invoke inherited here, to fully override parent DoClick method

  //It's common behavior when click on dropbox will show the list
  if fAutoClose then
    ListShow(Self)
  else
    if not ListVisible then
    begin
      fButton.TexId := 591;
      ListShow(Self)
    end else begin
      fButton.TexId := 590;
      ListHide(Self);
    end;

  inherited;
end;


//Handle KeyDown on List
function TKMDropCommon.ListKeyDown(Sender: TObject; Key: Word; Shift: TShiftState): Boolean;
begin
  if fAutoClose and (Key = VK_ESCAPE) then // Close List on ESC, if autoclosable
  begin
    ListHide(nil);
    Result := True;
  end else
    Result := False;
end;


procedure TKMDropCommon.ListClick(Sender: TObject);
begin
  //No need to call fOnChange here since ListChange was already called
  if fAutoClose then ListHide(nil);
end;


procedure TKMDropCommon.ListChange(Sender: TObject);
begin
  if (ItemIndex <> -1) then
    if Assigned(fOnChange) then fOnChange(Self);
end;


procedure TKMDropCommon.ListHide(Sender: TObject);
begin
  fShape.Hide;
end;


procedure TKMDropCommon.SetEnabled(aValue: Boolean);
begin
  inherited;
  fButton.Enabled := fEnabled;
end;


procedure TKMDropCommon.OpenList;
begin
  ListShow(nil);
end;


procedure TKMDropCommon.CloseList;
begin
  ListHide(nil);
end;


procedure TKMDropCommon.SetOpenList(aOpen: Boolean);
begin
  if aOpen then
    OpenList
  else
    CloseList;
end;


procedure TKMDropCommon.SwitchOpen;
begin
  if IsOpen then
    CloseList
  else
    OpenList;
end;


procedure TKMDropCommon.SetTop(aValue: Integer);
begin
  inherited;
  //Stick the button to us
  fButton.Top := Top;
end;


procedure TKMDropCommon.SetVisible(aValue: Boolean);
begin
  inherited;
  fButton.Visible := aValue;
  if not aValue then ListHide(Self);
end;


procedure TKMDropCommon.Paint;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  // Make sure the list stays where it needs to be relative DropBox (e.g. on window resize)
  UpdateDropPosition;
end;


{ TKMDropList }
constructor TKMDropList.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; const aDefaultCaption: UnicodeString;
                               aStyle: TKMButtonStyle; aAutoClose: Boolean = True; aBackAlpha: Single = 0.85; aPaintLayer: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aStyle, aAutoClose, aPaintLayer);

  fDefaultCaption := aDefaultCaption;

  fListTopIndex := 0;

  fList := TKMListBox.Create(MasterParent, 0, 0, aWidth, 0, fFont, aStyle, aPaintLayer);
  fList.Height := fList.ItemHeight * fDropCount;
  fList.AutoHideScrollBar := True; //A drop box should only have a scrollbar if required
  fList.BackAlpha := aBackAlpha;
  fList.fOnClick := ListClick;
  fList.fOnChange := ListChange;

  DropWidth := aWidth;

  ListHide(nil);
  fList.OnKeyDown := ListKeyDown;
end;


procedure TKMDropList.ListShow(Sender: TObject);
begin
  inherited;
  if ListVisible or (Count < 1) then Exit;

  //Make sure the selected item is visible when list is opened
  if (ItemIndex <> -1) then
  begin
    if InRange(ItemIndex, fListTopIndex, fListTopIndex + fList.GetVisibleRows) then //Try to open list at previously saved scroll position
      fList.TopIndex := fListTopIndex
    else
      fList.TopIndex := ItemIndex;
  end;

  fList.Show;
end;


procedure TKMDropList.ListClick(Sender: TObject);
begin
  fCaption := fList.Item[ItemIndex];

  inherited;
end;


procedure TKMDropList.ListChange(Sender: TObject);
begin
  fCaption := fList.Item[ItemIndex];

  inherited;
end;


procedure TKMDropList.ListHide(Sender: TObject);
begin
  fListTopIndex := fList.TopIndex; //Save list scroll position
  inherited;
  fList.Hide;
end;


function TKMDropList.ListVisible: Boolean;
begin
  Result := fList.Visible;
end;


function TKMDropList.GetItemIndex: Smallint;
begin
  Result := fList.ItemIndex;
end;


procedure TKMDropList.SetItemIndex(aIndex: Smallint);
begin
  fList.ItemIndex := aIndex;
  if aIndex <> -1 then
    fCaption := fList.Item[fList.ItemIndex]
  else
    fCaption := fDefaultCaption;
end;


function TKMDropList.GetShowHintWhenShort: Boolean;
begin
  Result := fList.ShowHintWhenShort;
end;


procedure TKMDropList.SetShowHintWhenShort(const aValue: Boolean);
begin
  fList.ShowHintWhenShort := aValue;
end;


function TKMDropList.IsOpen: Boolean;
begin
  Result := fList.Visible;
end;


procedure TKMDropList.SetDropWidth(aDropWidth: Integer);
begin
  fDropWidth := aDropWidth;
  fList.AbsLeft := AbsLeft + Width - aDropWidth;
  fList.Width := aDropWidth;
end;


procedure TKMDropList.SetEnabled(aValue: Boolean);
begin
  inherited;
  fList.Enabled := fEnabled;
  if not fEnabled and fList.Visible then
    ListHide(nil);
end;


procedure TKMDropList.SetVisible(aValue: Boolean);
begin
  inherited;
  if not aValue then ListHide(Self);
end;


function TKMDropList.Count: Integer;
begin
  Result := fList.Count;
end;


// When new items are added to the list we must update the drop height and position
procedure TKMDropList.UpdateDropPosition;
begin
  if Count > 0 then
  begin
    fList.Height := Math.Min(fDropCount, fList.Count) * fList.ItemHeight + fList.SeparatorsCount*fList.SeparatorHeight;

    if fDropUp then
      fList.AbsTop := AbsTop - fList.Height
    else
      fList.AbsTop := AbsTop + Height;

    fList.Left := AbsLeft + Width - DropWidth - MasterParent.AbsLeft;
  end;
end;


procedure TKMDropList.Add(const aItem: UnicodeString; aTag: Integer = 0);
begin
  fList.Add(aItem, aTag);
end;


procedure TKMDropList.SelectByName(const aText: UnicodeString);
var I: Integer;
begin
  fList.ItemIndex := -1;
  for I := 0 to fList.Count - 1 do
    if fList.Item[I] = aText then
      SetItemIndex(I);
end;


procedure TKMDropList.SelectByTag(aTag: Integer);
var I: Integer;
begin
  fList.ItemIndex := -1;
  for I := 0 to fList.Count - 1 do
    if fList.ItemTags[I] = aTag then
      SetItemIndex(I);
end;


function TKMDropList.HasTag(aTag: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to fList.Count - 1 do
    if fList.ItemTags[I] = aTag then
      Exit(True);
end;


function TKMDropList.IsSelected: Boolean;
begin
  Result := fList.ItemIndex <> -1;
end;


function TKMDropList.GetTag(aIndex: Integer): Integer;
begin
  Result := fList.ItemTags[aIndex];
end;


function TKMDropList.GetSelectedTag: Integer;
begin
  Result := GetTag(fList.fItemIndex);
end;

function TKMDropList.GetItem(aIndex: Integer): UnicodeString;
begin
  Result := fList.Item[aIndex];
end;


procedure TKMDropList.Clear;
begin
  fList.Clear;
end;


procedure TKMDropList.Paint;
var
  col: TColor4;
begin
  inherited;

  if fEnabled then
    col := icWhite
  else
    col := icGray2;

  TKMRenderUI.WriteText(AbsLeft+4, AbsTop+4, Width-8, fCaption, fFont, taLeft, col);
end;


{ TKMDropColumns }
constructor TKMDropColumns.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; const aDefaultCaption: UnicodeString; aStyle: TKMButtonStyle; aShowHeader: Boolean = True);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aStyle);

  fListTopIndex := 0;

  fDefaultCaption := aDefaultCaption;

  fList := TKMColumnBox.Create(MasterParent, 0, 0, aWidth, 0, fFont, aStyle);
  fList.BackAlpha := 0.85;
  fList.OnClick := ListClick;
  fList.OnChange := ListChange;
  fList.ShowHeader := aShowHeader;

  DropWidth := aWidth;

  ListHide(nil);
  fList.OnKeyDown := ListKeyDown;
end;


procedure TKMDropColumns.ListShow(Sender: TObject);
begin
  inherited;
  if ListVisible or (Count < 1) then Exit;

  //Make sure the selected item is visible when list is opened
  if (ItemIndex <> -1) then
  begin
    if InRange(ItemIndex, fListTopIndex, fListTopIndex + fList.GetVisibleRows) then //Try to open list at previously saved scroll position
      fList.TopIndex := fListTopIndex
    else
      fList.TopIndex := ItemIndex;
  end;

  fList.Show;
end;


procedure TKMDropColumns.ListClick(Sender: TObject);
begin
  inherited;
end;


procedure TKMDropColumns.ListChange(Sender: TObject);
begin
  inherited;
end;


procedure TKMDropColumns.ListHide(Sender: TObject);
begin
  fListTopIndex := fList.TopIndex; //Save list scroll position
  inherited;
  fList.Hide;
end;


function TKMDropColumns.ListVisible: Boolean;
begin
  Result := fList.Visible;
end;


function TKMDropColumns.GetItemIndex: smallint;
begin
  Result := fList.ItemIndex;
end;


procedure TKMDropColumns.SetItemIndex(aIndex: smallint);
begin
  fList.ItemIndex := aIndex;
end;


procedure TKMDropColumns.SetDropWidth(aDropWidth: Integer);
begin
  fDropWidth := aDropWidth;
  fList.AbsLeft := AbsLeft + Width - aDropWidth;
  fList.Width := aDropWidth;
end;


function TKMDropColumns.GetShowHintWhenShort: Boolean;
begin
  Result := fList.ShowHintWhenShort
end;


procedure TKMDropColumns.SetShowHintWhenShort(const aValue: Boolean);
begin
  fList.ShowHintWhenShort := aValue;
end;


procedure TKMDropColumns.SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word);
var
  I: Integer;
  columnsToShowWhenListHidden: array of Boolean;
begin
  SetLength(columnsToShowWhenListHidden, Length(aColumns));
  for I := Low(columnsToShowWhenListHidden) to High(columnsToShowWhenListHidden) do
    columnsToShowWhenListHidden[I] := True; // by default show all columns
  SetColumns(aFont, aColumns, aColumnOffsets, columnsToShowWhenListHidden);
end;


procedure TKMDropColumns.SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word; aColumnsToShowWhenListHidden: array of Boolean);
var
  I: Integer;
begin
  Assert(Length(aColumns) = Length(aColumnsToShowWhenListHidden));
  fList.SetColumns(aFont, aColumns, aColumnOffsets);
  SetLength(fColumnsToShowWhenListHidden, Length(aColumnsToShowWhenListHidden));
  for I := Low(aColumnsToShowWhenListHidden) to High(aColumnsToShowWhenListHidden) do
    fColumnsToShowWhenListHidden[I] := aColumnsToShowWhenListHidden[I];
end;


procedure TKMDropColumns.SetEnabled(aValue: Boolean);
begin
  inherited;
  fList.Enabled := fEnabled;
end;


procedure TKMDropColumns.SetVisible(aValue: Boolean);
begin
  inherited;
  if not aValue then ListHide(Self);
end;


function TKMDropColumns.Count: Integer;
begin
  Result := fList.RowCount;
end;


//When new items are added to the list we must update the drop height and position
procedure TKMDropColumns.UpdateDropPosition;
begin
  if Count > 0 then
  begin
    fList.Height := Math.Min(fDropCount, fList.RowCount) * fList.ItemHeight + fList.Header.Height * Ord(fList.ShowHeader);

    if fDropUp then
      fList.AbsTop := AbsTop - fList.Height
    else
      fList.AbsTop := AbsTop + Height;

    fList.Left := AbsLeft + Width - DropWidth - MasterParent.AbsLeft;
  end;
end;


procedure TKMDropColumns.Add(aItem: TKMListRow);
begin
  fList.AddItem(aItem);
end;


function TKMDropColumns.GetItem(aIndex: Integer): TKMListRow;
begin
  Result := fList.Rows[aIndex];
end;


procedure TKMDropColumns.Clear;
begin
  fList.Clear;
end;


procedure TKMDropColumns.Paint;
var
  col: TColor4;
begin
  inherited;

  if fEnabled then
    col := icWhite
  else
    col := icGray2;

  if ItemIndex = -1 then
    TKMRenderUI.WriteText(AbsLeft + 4, AbsTop + 4, Width - 8 - fButton.Width, fDefaultCaption, fFont, taLeft, col)
  else
    fList.DoPaintLine(ItemIndex, AbsLeft, AbsTop, Width - fButton.Width, fColumnsToShowWhenListHidden, False);
end;


{ TKMDropColorBox }
constructor TKMDropColors.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight,aCount: Integer);
var
  MP: TKMPanel;
  size: Integer;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fColorIndex := 0;
  fRandomCaption := ''; //Disable random by default
  fOnClick := ListShow; //It's common behavior when click on dropbox will show the list

  fButton := TKMButton.Create(aParent, aLeft+aWidth-aHeight, aTop, aHeight, aHeight, 5, rxGui, bsMenu);
  fButton.fOnClick := ListShow;
  fButton.MakesSound := false;

  MP := MasterParent;
  fShape := TKMShape.Create(MP, 0, 0, MP.Width, MP.Height);
  fShape.fOnClick := ListHide;

  size := Round(Sqrt(aCount)+0.5); //Round up

  fSwatch := TKMColorSwatch.Create(MP, 0, 0, size, size, aWidth div size);
  fSwatch.BackAlpha := 0.75;
  fSwatch.fOnClick := ListClick;

  ListHide(nil);
end;


procedure TKMDropColors.ListShow(Sender: TObject);
begin
  if fSwatch.Visible then
  begin
    ListHide(nil);
    Exit;
  end;

  fSwatch.Show;
  fShape.Show;
end;


procedure TKMDropColors.ListClick(Sender: TObject);
begin
  fColorIndex := fSwatch.ColorIndex;
  if Assigned(fOnChange) then fOnChange(Self);
  ListHide(nil);
end;


procedure TKMDropColors.ListHide(Sender: TObject);
begin
  fSwatch.Hide;
  fShape.Hide;
end;


procedure TKMDropColors.SetEnabled(aValue: Boolean);
begin
  inherited;
  fButton.Enabled := fEnabled;
  fSwatch.Enabled := fEnabled;
end;


//Set ColorIndex to fSwatch as well since it holds the actual color that we use on Paint
procedure TKMDropColors.SetColorIndex(aIndex: Integer);
begin
  fColorIndex := aIndex;
  fSwatch.ColorIndex := aIndex;
end;


procedure TKMDropColors.UpdateDropPosition;
begin
  fSwatch.Left := AbsLeft;
  fSwatch.Top := AbsTop + Height;
end;


procedure TKMDropColors.SetColors(const aColors: array of TColor4; const aRandomCaption: UnicodeString = '');
begin
  //Store local copy of flag to substitute 0 color with "Random" text
  fRandomCaption := aRandomCaption;
  fSwatch.SetColors(aColors, (fRandomCaption <> ''));
end;


procedure TKMDropColors.Paint;
var
  col: TColor4;
begin
  inherited;

  UpdateDropPosition;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width-fButton.Width, Height);
  TKMRenderUI.WriteShape(AbsLeft+2, AbsTop+1, Width-fButton.Width-3, Height-2, fSwatch.GetColor);

  if (fRandomCaption <> '') and (fSwatch.ColorIndex = 0) then
  begin
    if fEnabled then col:=$FFFFFFFF else col:=$FF888888;
    TKMRenderUI.WriteText(AbsLeft+4, AbsTop+3, 0, fRandomCaption, fntMetal, taLeft, col);
  end;
end;


{ TKMMinimap }
constructor TKMMinimapView.Create(aMinimap: TKMMinimap; aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aWithBevel: Boolean = False);
begin
  //Create Bevel first
  if aWithBevel then
    fBevel := TKMBevel.Create(aParent, aLeft - 4, aTop - 4, aWidth + 8, aHeight + 8);

  //Then Minimap control itself
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  //Radius of circle around player location
  fLocRad := 8;

  fMinimap := aMinimap;
  if fMinimap <> nil then
  begin
    fMinimap.SubOnUpdateTexture(UpdateTexture);
    fMinimap.SubOnResize(ResizeMinimap);

    fMapTex.Tex := TRender.GenerateTextureCommon(ftNearest, ftNearest);
  end;
end;


procedure TKMMinimapView.UpdateSizes;
begin
  if fMinimap.MapX > fMinimap.MapY then
  begin
    fPaintWidth := Width;
    fPaintHeight := Round(Height * fMinimap.MapY / Max(fMinimap.MapX, 1)); // X could = 0
    fLeftOffset := 0;
    fTopOffset := (Height - fPaintHeight) div 2;
  end
  else
  begin
    fPaintWidth := Round(Width * fMinimap.MapX / Max(fMinimap.MapY, 1)); // Y could = 0
    fPaintHeight := Height;
    fLeftOffset := (Width - fPaintWidth) div 2;
    fTopOffset := 0;
  end;
end;


procedure TKMMinimapView.SetViewport(aViewport: TKMViewport);
begin
  fView := aViewport;
end;


procedure TKMMinimapView.ResizeMinimap;
begin
  if Self = nil then Exit;

  fWidthPOT := MakePOT(fMinimap.MapX);
  fHeightPOT := MakePOT(fMinimap.MapY);
  fMapTex.U := fMinimap.MapX / fWidthPOT;
  fMapTex.V := fMinimap.MapY / fHeightPOT;
end;


procedure TKMMinimapView.UpdateTexture;
var
  wData: Pointer;
  I: Word;
begin
  if Self = nil then Exit;
  
  GetMem(wData, fWidthPOT * fHeightPOT * 4);

  if fMinimap.MapY > 0 then //if MapY = 0 then loop will overflow to MaxWord
  for I := 0 to fMinimap.MapY - 1 do
    Move(Pointer(NativeUint(fMinimap.Base) + I * fMinimap.MapX * 4)^,
         Pointer(NativeUint(wData) + I * fWidthPOT * 4)^, fMinimap.MapX * 4);

  TRender.UpdateTexture(fMapTex.Tex, fWidthPOT, fHeightPOT, tfRGBA8, wData);
  FreeMem(wData);

  UpdateSizes;
end;


function TKMMinimapView.LocalToMapCoords(X,Y: Integer): TKMPoint;
begin
  Result.X := EnsureRange(Trunc((X - AbsLeft - fLeftOffset) * (fMinimap.MapX + 1) / fPaintWidth),  1, fMinimap.MapX);
  Result.Y := EnsureRange(Trunc((Y - AbsTop  - fTopOffset ) * (fMinimap.MapY + 1) / fPaintHeight), 1, fMinimap.MapY);
end;


function TKMMinimapView.MapCoordsToLocal(X,Y: Single; const Inset: ShortInt = 0): TKMPoint;
begin
  Assert(Inset >= -1, 'Min allowed inset is -1, to be within TKMPoint range of 0..n');
  Result.X := AbsLeft + fLeftOffset + EnsureRange(Round(X * fPaintWidth /  fMinimap.MapX), Inset, fPaintWidth  - Inset);
  Result.Y := AbsTop  + fTopOffset  + EnsureRange(Round(Y * fPaintHeight / fMinimap.MapY), Inset, fPaintHeight - Inset);
end;


procedure TKMMinimapView.SetAnchors(aValue: TKMAnchorsSet);
begin
  inherited;

  if fBevel <> nil then
    fBevel.SetAnchors(aValue);
end;


procedure TKMMinimapView.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  MouseMove(X,Y,Shift);
end;


procedure TKMMinimapView.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  viewPos: TKMPoint;
begin
  inherited;

  if (ssLeft in Shift) and not fClickableOnce then
  begin
    viewPos := LocalToMapCoords(X,Y);
    if Assigned(fOnChange) then
      fOnChange(Self, viewPos.X, viewPos.Y);
  end;
end;


procedure TKMMinimapView.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  I: Integer;
  T, viewPos: TKMPoint;
begin
  inherited;

  if fClickableOnce then
  begin
    fClickableOnce := False; //Not clickable anymore
    viewPos := LocalToMapCoords(X,Y);
    if Assigned(fOnMinimapClick) then
      fOnMinimapClick(Self, viewPos.X, viewPos.Y);
  end;

  if fShowLocs then
  for I := 0 to MAX_HANDS - 1 do
  if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
  begin
    T := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
    if Sqr(T.X - X) + Sqr(T.Y - Y) < Sqr(fLocRad) then
    begin
      if Assigned(OnLocClick) then
        OnLocClick(I);

      //Do not repeat events for stacked locations
      Break;
    end;
  end;
end;


procedure TKMMinimapView.Paint;
const
  ALERT_RAD = 4;
var
  I, K: Integer;
  R: TKMRect;
  T, T1, T2: TKMPoint;
  minimapGame: TKMMiniMapGame;
begin
  inherited;

  if (fMinimap = nil) or (fMinimap.MapX * fMinimap.MapY = 0) then
    Exit;

  if (fMapTex.Tex <> 0) then
    TKMRenderUI.WriteTexture(AbsLeft + fLeftOffset, AbsTop + fTopOffset, fPaintWidth, fPaintHeight, fMapTex, $FFFFFFFF)
  else
    TKMRenderUI.WriteBevel(AbsLeft, AbsTop, fWidth, fHeight);

  //Alerts (under viewport rectangle)
  if fMinimap is TKMMiniMapGame then
  begin
    minimapGame := TKMMiniMapGame(fMinimap);

    if (minimapGame.Alerts <> nil) then
    for I := 0 to minimapGame.Alerts.Count - 1 do
    if minimapGame.Alerts[I].VisibleMinimap then
    begin
      T := MapCoordsToLocal(minimapGame.Alerts[I].Loc.X, minimapGame.Alerts[I].Loc.Y, ALERT_RAD);
      TKMRenderUI.WritePicture(T.X, T.Y, 0, 0, [],
                               minimapGame.Alerts[I].TexMinimap.RX, minimapGame.Alerts[I].TexMinimap.ID,
                               True, minimapGame.Alerts[I].TeamColor, Abs((TimeGet mod 1000) / 500 - 1));
    end;

    //Viewport rectangle
    if fView <> nil then
    begin
      R := fView.GetMinimapClip;
      if (R.Right - R.Left) * (R.Bottom - R.Top) > 0 then
        TKMRenderUI.WriteOutline(AbsLeft + fLeftOffset + Round((R.Left - 1)*fPaintWidth / fMinimap.MapX),
                                 AbsTop  + fTopOffset  + Round((R.Top - 1)*fPaintHeight / fMinimap.MapY),
                                 Round((R.Right - R.Left)*fPaintWidth / fMinimap.MapX),
                                 Round((R.Bottom - R.Top + 1)*fPaintHeight / fMinimap.MapY), 1, $FFFFFFFF);
    end;
  end;

  if fShowLocs then
  begin
    //Connect allied players
    for I := 0 to MAX_HANDS - 1 do
    if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
      for K := I + 1 to MAX_HANDS - 1 do
      if fMinimap.HandShow[K] and not KMSamePoint(fMinimap.HandLocs[K], KMPOINT_ZERO) then
        if (fMinimap.HandTeam[I] <> 0) and (fMinimap.HandTeam[I] = fMinimap.HandTeam[K]) then
        begin
          T1 := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
          T2 := MapCoordsToLocal(fMinimap.HandLocs[K].X, fMinimap.HandLocs[K].Y, fLocRad);
          TKMRenderUI.WriteLine(T1.X, T1.Y, T2.X, T2.Y, $FFFFFFFF);
        end;

    //Draw all the circles, THEN all the numbers so the numbers are not covered by circles when they are close
    for I := 0 to MAX_HANDS - 1 do
    if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
    begin
      T := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
      TKMRenderUI.WriteCircle(T.X, T.Y, fLocRad, fMinimap.HandColors[I]);
    end;

    for I := 0 to MAX_HANDS - 1 do
    if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
    begin
      T := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
      TKMRenderUI.WriteText(T.X, T.Y - 6, 0, IntToStr(I+1), fntOutline, taCenter);
    end;
  end;

  if not fEnabled then
    TKMRenderUI.WriteBevel(AbsLeft, AbsTop, fWidth+1, fHeight+1, 0, 0.5);
end;


{ TKMDragger }
constructor TKMDragger.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  //Original position is used to resrict movement
  fPositionX := 0;
  fPositionY := 0;
end;


procedure TKMDragger.SetBounds(aMinusX, aMinusY, aPlusX, aPlusY: Integer);
begin
  fMinusX := aMinusX;
  fMinusY := aMinusY;
  fPlusX  := aPlusX;
  fPlusY  := aPlusY;
end;


procedure TKMDragger.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  fStartDragX := X - fPositionX;
  fStartDragY := Y - fPositionY;

  MouseMove(X,Y,Shift);
end;


procedure TKMDragger.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;

  if csDown in State then
  begin
    //Bounds are signed numbers, set them properly
    fPositionX := EnsureRange((X - fStartDragX), fMinusX, fPlusX);
    fPositionY := EnsureRange((Y - fStartDragY), fMinusY, fPlusY);

    if Assigned(OnMove) then OnMove(Self, fPositionX, fPositionY);
  end;
end;


procedure TKMDragger.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X,Y,Shift);
end;


procedure TKMDragger.Paint;
var
  stateSet: TKMButtonStateSet;
begin
  inherited;
  stateSet := [];
  if (csOver in State) and fEnabled then
    stateSet := stateSet + [bsOver];
  if (csDown in State) then
    stateSet := stateSet + [bsDown];
  if not fEnabled then
    stateSet := stateSet + [bsDisabled];

  TKMRenderUI.Write3DButton(AbsLeft, AbsTop, Width, Height, rxGui, 0, $FFFF00FF, stateSet, bsGame);
end;


{ TKMChart }
constructor TKMChart.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fSeparatorPositions := TXStringList.Create;
  fSeparatorPositions.Sorted := True; // Better we have separators sorted

  fFont := fntOutline;
  fItemHeight := 20;
  fLineOver := -1;
  fLegendWidth := 150;
  fSeparatorColor := clChartSeparator;
  fSeparatorHeight := 10;
end;


destructor TKMChart.Destroy;
begin
  FreeAndNil(fSeparatorPositions);
  inherited;
end;


procedure TKMChart.AddLine(const aTitle: UnicodeString; aColor: TColor4; const aValues: TKMCardinalArray; aTag: Integer = -1);
var
  titleDetailed: TKMStringArray;
  titleDetailedColor: TKMCardinalArray;
begin
  SetLength(titleDetailed, 0);
  SetLength(titleDetailedColor, 0);
  AddLine(aTitle, aColor, titleDetailed, titleDetailedColor, aValues, aTag);
end;


procedure TKMChart.AddLine(const aTitle: UnicodeString; aColor: TColor4; const aTitleDetailed: TKMStringArray;
                           const aTitleDetailedColor: TKMCardinalArray; const aValues: TKMCardinalArray; aTag: Integer = -1);
begin
  if fMaxLength = 0 then Exit;

  Assert(Length(aTitleDetailed) = Length(aTitleDetailedColor), 'aTitleDetailed and aTitleDetailedColor should have same length');

  //Make sure there is enough Values to copy to local storage with Move procedure
  Assert(Length(aValues) >= fMaxLength);

  SetLength(fLines, fCount + 1);

  fLines[fCount].Color := aColor;
  fLines[fCount].Title := aTitle;
  fLines[fCount].Tag := aTag;
  fLines[fCount].Visible := True;
  fLines[fCount].TitleDetailed := aTitleDetailed;
  fLines[fCount].TitleDetailedColor := aTitleDetailedColor;
  SetLength(fLines[fCount].Values, fMaxLength);
  if SizeOf(aValues) <> 0 then
    Move(aValues[0], fLines[fCount].Values[0], SizeOf(aValues[0]) * fMaxLength);
  Inc(fCount);

  UpdateMaxValue;
end;


function TKMChart.GetSeparatorPos(aIndex: Integer): Integer;
begin
  Result := -1;
  if not InRange(aIndex, 0, fSeparatorPositions.Count - 1) then Exit;

  Result := StrToInt(fSeparatorPositions[aIndex]);
end;


//function TKMChart.GetSeparatorsHeight(aIndex: Integer): Integer;
//var
//  I, Pos: Integer;
//begin
//  Result := 0;
//  for I := 0 to fSeparatorPositions.Count - 1 do
//  begin
//    Pos := SeparatorPos[I];
//    if (Pos <> -1) and (Pos <= aIndex) then
//      Inc(Result, fSeparatorHeight);
//  end;
//end;


procedure TKMChart.AddSeparator(aPosition: Integer);
begin
  fSeparatorPositions.Add(IntToStr(aPosition));
end;


procedure TKMChart.SetSeparatorPositions(aSeparatorPositions: TStringList);
begin
  fSeparatorPositions.Clear;
  fSeparatorPositions.AddStrings(aSeparatorPositions);
end;


//Add alternative values line (e.g. wares count vs. wares produced)
procedure TKMChart.AddAltLine(const aAltValues: TKMCardinalArray);
begin
  Assert(Length(aAltValues) >= fMaxLength);

  SetLength(fLines[fCount-1].ValuesAlt, fMaxLength);
  if SizeOf(aAltValues) <> 0 then
    Move(aAltValues[0], fLines[fCount-1].ValuesAlt[0], SizeOf(aAltValues[0]) * fMaxLength);

  UpdateMaxValue;
end;


//Trims the graph until 5% before the first variation
procedure TKMChart.TrimToFirstVariation;
var
  I, K, firstVarSample: Integer;
  startVal: Cardinal;
begin
  firstVarSample := -1;
  for I:=0 to fCount-1 do
    if Length(fLines[I].Values) > 0 then
    begin
      startVal := fLines[I].Values[0];
      for K:=1 to Length(fLines[I].Values)-1 do
        if fLines[I].Values[K] <> startVal then
        begin
          if (K < firstVarSample) or (firstVarSample = -1) then
            firstVarSample := K - 1;
          Break;
        end;
    end;
  if firstVarSample <= 0 then
  begin
    fMinTime := 0; //No variation at all, so don't trim it (but clear previous value)
    Exit;
  end;
  //Take 5% before the first varied sample
  firstVarSample := Max(0, firstVarSample - Max(1, Round(0.05*(fMaxLength - firstVarSample))));
  //Trim all fLines[I].Values to start at FirstVarSample
  for I := 0 to fCount - 1 do
  begin
    Move(fLines[I].Values[firstVarSample], fLines[I].Values[0], (Length(fLines[I].Values)-firstVarSample)*SizeOf(fLines[I].Values[0]));
    SetLength(fLines[I].Values, Length(fLines[I].Values)-firstVarSample);
  end;
  //Set start time so the horizontal time ticks are rendered correctly
  fMinTime := Round((firstVarSample/fMaxLength) * fMaxTime);
  //All lines have now been trimmed, so update fMaxLength
  fMaxLength := fMaxLength - firstVarSample;
end;


procedure TKMChart.Clear;
begin
  fCount := 0;
  SetLength(fLines, 0);
  fMaxValue := 0;
  ClearSeparators;
end;


procedure TKMChart.ClearSeparators;
begin
  fSeparatorPositions.Clear;
end;


procedure TKMChart.SetLineVisible(aLineID: Integer; aVisible: Boolean);
begin
  fLines[aLineID].Visible := aVisible;
  UpdateMaxValue;
end;


procedure TKMChart.UpdateMaxValue;
var
  I, K: Integer;
begin
  fMaxValue := 0;
  for I := 0 to fCount - 1 do
    if fLines[I].Visible then
      for K := 0 to fMaxLength - 1 do
        if fLines[I].Values[K] > fMaxValue then
          fMaxValue := fLines[I].Values[K];
end;


function TKMChart.GetLine(aIndex: Integer): TKMGraphLine;
begin
  Result := fLines[aIndex];
end;


function TKMChart.GetLineNumber(aY: Integer): Integer;
var
  I, S, lineTop, lineBottom: Integer;
begin
  Result := -1;
  S := 0;
  lineTop := AbsTop + 5 + 20*Byte(fLegendCaption <> '');
  for I := 0 to fCount - 1 do
  begin
    if SeparatorPos[S] = I then
    begin
      Inc(lineTop, fSeparatorHeight);
      Inc(S);
    end;
    lineBottom := lineTop + fItemHeight*(1 + Length(Lines[I].TitleDetailed));
    if InRange(aY, lineTop, lineBottom) then
    begin
      Result := I;
      Exit;
    end;
    lineTop := lineBottom;
  end;
end;


procedure TKMChart.MouseMove(X, Y: Integer; Shift: TShiftState);
begin
  inherited;

  fLineOver := -1;
  if X < AbsLeft + Width - fLegendWidth + 5 then Exit;
  fLineOver := GetLineNumber(Y);
end;


procedure TKMChart.MouseUp(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  I: Integer;
begin
  inherited;

  if X < AbsLeft + Width - fLegendWidth+5 then Exit;

  I := GetLineNumber(Y);
  if not InRange(I, 0, fCount - 1) then Exit;

  fLines[I].Visible := not fLines[I].Visible;

  UpdateMaxValue;

  if Assigned(fOnLegendClick) then
    fOnLegendClick(Self, I, fLines[I].Visible);
end;


procedure TKMChart.Paint;
const
  IntervalCount: array [0..9] of Word = (1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000);
  IntervalTime: array [0..10] of Word = (30, 1*60, 5*60, 10*60, 15*60, 30*60, 1*60*60, 2*60*60, 3*60*60, 4*60*60, 5*60*60);

var
  G: TKMRect;
  topValue: Integer;

  procedure PaintAxisLabel(aTime: Integer; aIsPT: Boolean = False);
  var
    XPos: Integer;
  begin
    XPos := G.Left + Round((aTime - fMinTime) / (fMaxTime-fMinTime) * (G.Right - G.Left));
    TKMRenderUI.WriteShape(XPos, G.Bottom - 2, 2, 5, IfThen(aIsPT, clChartPeacetimeLn, icWhite));
    TKMRenderUI.WriteText (XPos, G.Bottom + 4, 0, TimeToString(aTime / 24 / 60 / 60), fntGame, taLeft, IfThen(aIsPT, clChartPeacetimeLbl, icWhite));
    TKMRenderUI.WriteLine(XPos, G.Top, XPos, G.Bottom, IfThen(aIsPT, clChartPeacetimeLn, clChartDashedVLn), $CCCC);
    if aIsPT then
      TKMRenderUI.WriteText(XPos - 3, G.Bottom + 4, 0, gResTexts[TX_CHART_PT_END], fntGame, taRight, clChartPeacetimeLbl);
  end;

  procedure RenderHorizontalAxisTicks;
  var
    I, Best: Integer;
  begin
    //Find first time interval that will have less than 10 ticks
    Best := 0;
    for I := Low(IntervalTime) to High(IntervalTime) do
      if (fMaxTime-fMinTime) div IntervalTime[I] < 7 then
      begin
        Best := IntervalTime[I];
        Break;
      end;

    //Paint time axis labels
    if (Best <> 0) and (fMaxTime <> fMinTime) then
      if (fPeaceTime <> 0) and InRange(fPeaceTime, fMinTime, fMaxTime) then
      begin
        //Labels before PT and PT himself
        for I := 0 to ((fPeaceTime - fMinTime) div Best) do
          PaintAxisLabel(fPeaceTime - I * Best, I = 0);

        //Labels after PT
        for I := 1 to ((fMaxTime - fPeaceTime) div Best) do
          PaintAxisLabel(fPeaceTime + I * Best);
      end else
        for I := Ceil(fMinTime / Best) to (fMaxTime div Best) do
          PaintAxisLabel(I * Best);
  end;

  function GetLineColor(aColor: Cardinal): Cardinal;
  begin
    //Adjust the color if it blends with black background
    Result := EnsureBrightness(aColor, 0.3);

    // If color is similar to highlight color, then use alternative HL color
    if GetColorDistance(Result, clChartHighlight) < 0.1 then
      Result := clChartHighlight2;
  end;

  procedure RenderChartAndLegend;
  const
    MARKS_FONT: TKMFont = fntGrey;
  var
    I, J, S, CheckSize, XPos, YPos, Height: Integer;
    TitleDetailedH: Integer;
    NewColor: TColor4;
  begin
    CheckSize := gRes.Fonts[MARKS_FONT].GetTextSize('v').Y + 1;
    S := 0;
    XPos := G.Right + 10;
    YPos := G.Top + 8 + 20*Byte(fLegendCaption <> '');

    TitleDetailedH := 0;
    //Charts and legend
    for I := 0 to fCount - 1 do
    begin
      NewColor := GetLineColor(fLines[I].Color);

      if (csOver in State) and (I = fLineOver) then
        NewColor := clChartHighlight;

      //Charts
      if fLines[I].Visible then
      begin
        TKMRenderUI.WritePlot(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, fLines[I].Values, topValue, NewColor, 2);
        if Length(fLines[I].ValuesAlt) > 0 then
          TKMRenderUI.WritePlot(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, fLines[I].ValuesAlt, topValue, NewColor, 1);
      end;

      if SeparatorPos[S] = I then
      begin
        Inc(YPos, fSeparatorHeight);
        Inc(S);
      end;

      //Checkboxes
      TKMRenderUI.WriteBevel(XPos, YPos, CheckSize - 4, CheckSize - 4, 1, 0.3);
      TKMRenderUI.WriteOutline(XPos, YPos, CheckSize - 4, CheckSize - 4, 1, clChkboxOutline);
      if fLines[I].Visible then
        TKMRenderUI.WriteText(XPos + (CheckSize-4) div 2, YPos - 1, 0, 'v', MARKS_FONT, taCenter, NewColor);

      //Legend
      TKMRenderUI.WriteText(XPos + CheckSize, YPos, 0, fLines[I].Title, fntGame, taLeft, NewColor);
      Inc(YPos, fItemHeight);

      //Detailed legend
      for J := Low(fLines[I].TitleDetailed) to High(fLines[I].TitleDetailed) do
      begin
        TKMRenderUI.WriteText(XPos + CheckSize + 5, YPos, 0, fLines[I].TitleDetailed[J], fntGrey, taLeft, GetLineColor(fLines[I].TitleDetailedColor[J]));
        Inc(YPos, fItemHeight);
        Inc(TitleDetailedH, fItemHeight);
      end;
    end;

    //Legend title and outline
    Height := fItemHeight*fCount + TitleDetailedH + 6 + 20*Byte(fLegendCaption <> '') + fSeparatorPositions.Count*fSeparatorHeight;
    TKMRenderUI.WriteShape(G.Right + 5, G.Top, fLegendWidth, Height, icDarkestGrayTrans);
    TKMRenderUI.WriteOutline(G.Right + 5, G.Top, fLegendWidth, Height, 1, icGray);
    if fLegendCaption <> '' then
      TKMRenderUI.WriteText(G.Right + 5, G.Top + 4, fLegendWidth, fLegendCaption, fntMetal, taCenter, icWhite);
  end;

var
  I: Integer;
  best, tmp: Integer;
begin
  inherited;

  G := KMRect(AbsLeft + 40, AbsTop, AbsLeft + Width - fLegendWidth, AbsTop + Height - 20);

  //Add margin to MaxValue so that it does not blends with upper border
  topValue := Max(Round(fMaxValue * 1.1), fMaxValue + 1);

  //Find first interval that will have less than 10 ticks
  best := 0;
  for I := Low(IntervalCount) to High(IntervalCount) do
    if topValue div IntervalCount[I] < 10 then
    begin
      best := IntervalCount[I];
      Break;
    end;

  //Dashed lines in the background
  if best <> 0 then
    for I := 1 to (topValue div best) do
    begin
      tmp := G.Top + Round((1 - I * best / topValue) * (G.Bottom - G.Top));
      TKMRenderUI.WriteText(G.Left - 5, tmp - 6, 0, IntToStr(I * best), fntGame, taRight);
      TKMRenderUI.WriteLine(G.Left, tmp, G.Right, tmp, clChartDashedHLn, $CCCC);
    end;

  //Render horizontal axis ticks
  RenderHorizontalAxisTicks;

  RenderChartAndLegend;

  //Render the highlighted line above all the others and thicker so you can see where it goes under others
  if (csOver in State) and InRange(fLineOver, 0, fCount-1) and fLines[fLineOver].Visible then
    TKMRenderUI.WritePlot(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, fLines[fLineOver].Values, topValue, clChartHighlight, 3);

  //Outline
  TKMRenderUI.WriteOutline(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, 1, icWhite);

  //Title
  TKMRenderUI.WriteText(G.Left + 5, G.Top + 5, 0, fCaption, fFont, taLeft);

  //Render vertical axis captions
  TKMRenderUI.WriteText(G.Left - 5, G.Bottom - 6, 0, IntToStr(0), fntGame, taRight);
  //TKMRenderUI.WriteText(Left+20, Top + 20, 0, 0, IntToStr(fMaxValue), fntGame, taRight);

end;


{ TKMMasterControl }
constructor TKMMasterControl.Create;
begin
  inherited;

  fMouseMoveSubsList := TList<TKMMouseMoveEvent>.Create;
  fMouseDownSubsList := TList<TKMMouseUpDownEvent>.Create;
  fMouseUpSubsList := TList<TKMMouseUpDownEvent>.Create;
end;


destructor TKMMasterControl.Destroy;
begin
  fMouseUpSubsList.Free;
  fMouseDownSubsList.Free;
  fMouseMoveSubsList.Free;

  // Free and nil to avoid problems on game Exit (MouseMove invokes ScanChilds over object, while he is going to be freed)
  // So we want to object to be nil'ed first, so we could check it in the ScanChilds
  // Will destroy all its childs as well
  FreeAndNil(fMasterPanel);

  inherited;
end;


procedure TKMMasterControl.AddMouseMoveCtrlSub(const aMouseMoveEvent: TKMMouseMoveEvent);
begin
  if Self = nil then Exit;

  fMouseMoveSubsList.Add(aMouseMoveEvent);
end;


procedure TKMMasterControl.AddMouseDownCtrlSub(const aMouseDownEvent: TKMMouseUpDownEvent);
begin
  if Self = nil then Exit;

  fMouseDownSubsList.Add(aMouseDownEvent);
end;


procedure TKMMasterControl.AddMouseUpCtrlSub(const aMouseUpEvent: TKMMouseUpDownEvent);
begin
  if Self = nil then Exit;

  fMouseUpSubsList.Add(aMouseUpEvent);
end;


procedure TKMMasterControl.SetCtrlDown(aCtrl: TKMControl);
begin
  if fCtrlDown <> nil then
    fCtrlDown.State := fCtrlDown.State - [csDown]; //Release previous

  if aCtrl <> nil then
    aCtrl.State := aCtrl.State + [csDown];         //Press new

  fCtrlDown := aCtrl;                              //Update info
end;


procedure TKMMasterControl.SetCtrlFocus(aCtrl: TKMControl);
begin
  if fCtrlFocus <> nil then
    fCtrlFocus.State := fCtrlFocus.State - [csFocus];

  if aCtrl <> nil then
    aCtrl.State := aCtrl.State + [csFocus];

  if aCtrl <> fCtrlFocus then
  begin
    if fCtrlFocus <> nil then
    begin
      fCtrlFocus.FocusChanged(False);
      if fCtrlFocus <> nil then
      begin
        if  Assigned(fCtrlFocus.fOnFocus) then
            fCtrlFocus.fOnFocus(fCtrlFocus, False);
        // Reset Parent Panel FocusedControlIndex only for different parents
        if (aCtrl = nil) or (aCtrl.Parent <> fCtrlFocus.Parent) then
            fCtrlFocus.Parent.ResetFocusedControlIndex;
      end;
    end;

    if aCtrl <> nil then
    begin
      aCtrl.FocusChanged(True);
      if Assigned(aCtrl.fOnFocus) then
        aCtrl.fOnFocus(aCtrl, True);
      aCtrl.Parent.FocusedControlIndex := aCtrl.ControlIndex; //Set Parent Panel FocusedControlIndex to new focused control
    end;
  end;

  fCtrlFocus := aCtrl;
end;


procedure TKMMasterControl.SetCtrlOver(aCtrl: TKMControl);
begin
  if fCtrlOver <> nil then fCtrlOver.State := fCtrlOver.State - [csOver];
  if aCtrl <> nil then aCtrl.State := aCtrl.State + [csOver];
  fCtrlOver := aCtrl;
end;


procedure TKMMasterControl.SetCtrlUp(aCtrl: TKMControl);
begin
  fCtrlUp := aCtrl;
  //Give focus only to controls with Focusable=True
  if (fCtrlUp <> nil) and fCtrlUp.Focusable then
    if fCtrlDown = fCtrlUp then
      CtrlFocus := fCtrlUp
    else
      CtrlFocus := nil;
end;


//Check If Control if it is allowed to be focused on (manual or automatically)
function TKMMasterControl.IsFocusAllowed(aCtrl: TKMControl): Boolean;
begin
  if Self = nil then Exit(False);

  Result := aCtrl.fVisible
        and aCtrl.Enabled
        and aCtrl.Focusable
        and not IsCtrlCovered(aCtrl); // Do not allow to focus on covered Controls
end;


//Check If Control if it is allowed to be automatically (not manual, by user) focused on
function TKMMasterControl.IsAutoFocusAllowed(aCtrl: TKMControl): Boolean;
begin
  if Self = nil then Exit(False);

  Result := aCtrl.AutoFocusable and IsFocusAllowed(aCtrl);
end;


function TKMMasterControl.GetNextCtrlID: Integer;
begin
  Inc(fControlIDCounter);
  Result := fControlIDCounter;
end;


//Update focused control
procedure TKMMasterControl.UpdateFocus(aSender: TKMControl);

  function FindFocusable(C: TKMPanel): Boolean;
  var
    I: Integer;
    ctrl: TKMControl;
  begin
    Result := False;
    ctrl := C.FindFocusableControl(False);
    if ctrl <> nil then
    begin
      CtrlFocus := ctrl;
      Result := True;
      Exit;
    end;

    for I := 0 to C.ChildCount - 1 do
      if C.Childs[I].fVisible
        and C.Childs[I].Enabled
        and (C.Childs[I] is TKMPanel) then
      begin
        Result := FindFocusable(TKMPanel(C.Childs[I]));
        if Result then Exit;
      end;
  end;

begin
  if Self = nil then Exit;

  if aSender.Visible and aSender.Enabled
    and ((not (aSender is TKMPanel) and aSender.Focusable) or (aSender is TKMPanel)) then
  begin
    // Something showed up or became enabled

    // If something showed up - focus on it
    if not (aSender is TKMPanel) and aSender.Focusable then
      CtrlFocus := aSender;
    // If panel showed up - try to focus on its contents
    if aSender is TKMPanel then
      FindFocusable(TKMPanel(aSender));
  end else
  begin
    // Something went hidden or disabled
    if (CtrlFocus = nil) or not CtrlFocus.Visible or not CtrlFocus.Enabled or not CtrlFocus.Focusable then
    begin
      // If there was no focus, or it is our Focus control that went hidden or disabled
      CtrlFocus := nil;
      FindFocusable(fMasterPanel);
    end;
  end;
end;


procedure TKMMasterControl.UpdateState(aGlobalTickCount: Cardinal);
begin
  if Self = nil then Exit;

  fMasterPanel.UpdateState(aGlobalTickCount);
end;


//Check if control is covered by other controls or not
//We assume that control is covered if any of his 4 corners is covered
//For corners used actual corners with 1 px offset inside to solve border collisions
//Use Self coordinates to check, because some controls can contain other sub-controls (f.e. TKMNumericEdit)
function TKMMasterControl.IsCtrlCovered(aCtrl: TKMControl): Boolean;
begin
  Result := (HitControl(aCtrl.SelfAbsLeft + 1, aCtrl.SelfAbsTop + 1) <> aCtrl)
        or (HitControl(aCtrl.SelfAbsLeft + aCtrl.SelfWidth - 1, aCtrl.SelfAbsTop + 1) <> aCtrl)
        or (HitControl(aCtrl.SelfAbsLeft + 1, aCtrl.SelfAbsTop + aCtrl.SelfHeight - 1) <> aCtrl)
        or (HitControl(aCtrl.SelfAbsLeft + aCtrl.SelfWidth - 1, aCtrl.SelfAbsTop + aCtrl.SelfHeight - 1) <> aCtrl);
end;


{ Recursing function to find topmost control (excl. Panels)}
function TKMMasterControl.HitControl(X,Y: Integer; aIncludeDisabled: Boolean = False; aIncludeNotHitable: Boolean = False): TKMControl;

  function ScanChild(P: TKMPanel; aX,aY: Integer): TKMControl;
  var
    I: Integer;
    child: TKMControl;
  begin
    // Could sometimes happen on game exit?
    if (Self = nil) or (P = nil) then Exit(nil);

    Result := nil;
    //Process controls in reverse order since last created are on top
    for I := P.ChildCount - 1 downto 0 do
    begin
      child := P.Childs[I];
      if child.fVisible then //If we can't see it, we can't touch it
      begin
        //Scan Panels childs first, if none is hit - hittest the panel
        if (child is TKMPanel) then
        begin
          Result := ScanChild(TKMPanel(child),aX,aY);
          if Result <> nil then
            Exit;
        end;
        if child.HitTest(aX, aY, aIncludeDisabled, aIncludeNotHitable) then
        begin
          Result := child;
          Exit;
        end;
      end;
    end;
  end;

begin
  if Self = nil then Exit(nil);

  Result := ScanChild(fMasterPanel, X, Y);
end;


function TKMMasterControl.KeyDown(Key: Word; Shift: TShiftState): Boolean;
var
  control: TKMControl;
begin
  Result := False;

  if Self = nil then Exit;

  //CtrlFocus could be on another menu page and no longer visible
  if (CtrlFocus <> nil) and CtrlFocus.Visible then
  begin
    control := CtrlFocus;
    //Lets try to find who can handle KeyDown event in controls tree
    while (control <> nil) and not control.KeyDown(Key, Shift) do
      control := control.Parent;

    Result := control <> nil; // means we find someone, who handle that event
  end;

  if MODE_DESIGN_CONTROLS and (CtrlOver <> nil) then
    CtrlOver.DebugKeyDown(Key, Shift);
end;


procedure TKMMasterControl.KeyPress(Key: Char);
begin
  if Self = nil then Exit;

  //CtrlFocus could be on another menu page and no longer visible
  if (CtrlFocus <> nil) and CtrlFocus.Visible then
    CtrlFocus.KeyPress(Key);
end;


function TKMMasterControl.KeyUp(Key: Word; Shift: TShiftState): Boolean;
var
  control: TKMControl;
begin
  Result := False;

  if Self = nil then Exit;

  //CtrlFocus could be on another menu page and no longer visible
  if (CtrlFocus <> nil) and CtrlFocus.Visible then
  begin
    control := CtrlFocus;
    //Lets try to find who can handle KeyUp event in controls tree
    while (control <> nil) and not control.KeyUp(Key, Shift) do
      control := control.Parent;

    Result := control <> nil; // means we find someone, who handle that event
  end;
end;


procedure TKMMasterControl.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  I: Integer;
begin
  if Self = nil then Exit;

  CtrlDown := HitControl(X,Y);

  // Notify all ControlMouseDown subscribers
  for I := 0 to fMouseDownSubsList.Count - 1 do
    if Assigned(fMouseDownSubsList[I]) then
      fMouseDownSubsList[I](CtrlDown, X, Y, Shift, Button);
//  fMasterPanel.ControlMouseDown(CtrlDown, X, Y, Shift, Button);

  if CtrlDown <> nil then
    CtrlDown.MouseDown(X, Y, Shift, Button);
end;


procedure TKMMasterControl.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  I: Integer;
begin
  if Self = nil then Exit;

  CtrlOver := HitControl(X,Y);

  // Notify all ControlMouseMove subscribers
  for I := 0 to fMouseMoveSubsList.Count - 1 do
    if Assigned(fMouseMoveSubsList[I]) then
      fMouseMoveSubsList[I](CtrlOver, X, Y, Shift);

  //User is dragging some Ctrl (e.g. scrollbar) and went away from Ctrl bounds
  if (CtrlDown <> nil) and CtrlDown.Visible then
    CtrlDown.MouseMove(X, Y, Shift)
  else
  if CtrlOver <> nil then
    CtrlOver.MouseMove(X, Y, Shift);

  //The Game hides cursor when using DirectionSelector, don't spoil it
  if gSystem.Cursor <> kmcInvisible then
    if CtrlOver is TKMEdit then
      gSystem.Cursor := kmcEdit
    else
    if CtrlOver is TKMDragger then
      gSystem.Cursor := kmcDragUp
    else
      if gSystem.Cursor in [kmcEdit, kmcDragUp] then
        gSystem.Cursor := kmcDefault; //Reset the cursor from these two special cursors
end;


procedure TKMMasterControl.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  I: Integer;
begin
  CtrlUp := HitControl(X,Y);

  //Here comes tricky part, we can't do anything after calling an event (it might Destroy everything,
  //e.g. Exit button, or Resolution change). We need to release CtrlDown (otherwise it remains
  //pressed), but we need to keep csDown state until it's registered by Control.MouseUp
  //to call OnClick. So, we nil fCtrlDown here and Control.MouseUp will reset ControlState
  //Other case, if we don't care for OnClick (CtrlDown<>CtrlUp) - just release the CtrDown as usual
  if CtrlDown <> CtrlUp then
    CtrlDown := nil
  else
    fCtrlDown := nil;


  // Notify all ControlMouseUp subscribers
  for I := 0 to fMouseUpSubsList.Count - 1 do
    if Assigned(fMouseUpSubsList[I]) then
      fMouseUpSubsList[I](CtrlUp, X, Y, Shift, Button);

//  fMasterPanel.ControlMouseUp(CtrlUp, X, Y, Shift, Button); // Must be invoked before CtrlUp.MouseUp to avoid problems on game Exit

  if CtrlUp <> nil then
    CtrlUp.MouseUp(X, Y, Shift, Button);

  //Do not place any code here, we could have Exited in OnClick event
end;


procedure TKMMasterControl.MouseWheel(X,Y: Integer; WheelSteps: Integer; var aHandled: Boolean);
var
  ctrl: TKMControl;
begin
  if Self = nil then Exit;

  ctrl := HitControl(X, Y);
  if ctrl <> nil then
    ctrl.MouseWheel(ctrl, WheelSteps, aHandled);
end;


{Paint controls}
{Leave painting of childs to their parent control}
procedure TKMMasterControl.Paint;
var
  I: Integer;
  str: string;
begin
  if Self = nil then Exit;

  CtrlPaintCount := 0;
  for I := 0 to fMaxPaintLayer do
  begin
    fCurrentPaintLayer := I;
    fMasterPanel.PaintPanel(I);
  end;

  if MODE_DESIGN_CONTROLS and (CtrlOver <> nil) then
  begin
    if GetKeyState(VK_CONTROL) < 0 then
      str := Format('%d:%d/%d:%d', [CtrlOver.AbsLeft, CtrlOver.AbsTop, CtrlOver.Width, CtrlOver.Height])
    else
      str := Format('%d:%d/%d:%d', [CtrlOver.Left, CtrlOver.Top, CtrlOver.Width, CtrlOver.Height]);

    TKMRenderUI.WriteText(CtrlOver.AbsLeft, CtrlOver.AbsTop - 14, 0, str, fntGrey, taLeft);
  end;
end;


procedure TKMMasterControl.SaveToFile(const aFileName: UnicodeString);
var
  ft: Textfile;
begin
  if Self = nil then Exit;

  AssignFile(ft,aFileName);
  Rewrite(ft);

  //fCtrl.SaveToFile; //Will save all the childs as well, recursively alike Paint or HitControl
  //writeln(ft, ClassName);
  //writeln(ft, Format('[%d %d %d %d]', [fLeft, fTop, fWidth, fHeight]));

  CloseFile(ft);
end;


{ TKMControl.TKMKeyPress }
//function TKMControl.TKMKeyPress.ToString: string;
//var
//  kindStr: string;
//begin
//  case Kind of
//    kpkDown:  kindStr := 'Down';
//    kpkPress: kindStr := 'Press';
//    else      kindStr := 'unknown';
//  end;
////  Result := Format('T=%d %s Key=%d C=%s ', [Integer(Time), kpkPress, Key, String(C)]);
//  Result := Format('T=%d %s C=%d ', [Integer(Time), kindStr, {Key, }Ord(c)]);
//end;


end.

