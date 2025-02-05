unit KM_GUIMapEdPlayerBlockTrade;
{$I KaM_Remake.inc}
interface
uses
   Classes,
   KM_Controls, KM_Pics, KM_InterfaceGame;

type
  TKMMapEdPlayerBlockTrade = class
  private
    procedure Player_BlockTradeClick(Sender: TObject; Shift: TShiftState);
    procedure Player_BlockTradeRefresh;
  protected
    Panel_BlockTrade: TKMPanel;
    Button_BlockTrade: array [1..STORE_RES_COUNT] of TKMButtonFlat;
    Image_BlockTrade: array [1..STORE_RES_COUNT] of TKMImage;
  public
    constructor Create(aParent: TKMPanel);

    procedure Show;
    function Visible: Boolean;
    procedure Hide;
  end;


implementation
uses
  KM_HandsCollection, KM_ResTexts,
  KM_Resource, KM_RenderUI, KM_ResFonts, KM_ResWares,
  KM_ResTypes;


{ TKMMapEdPlayerBlockTrade }
constructor TKMMapEdPlayerBlockTrade.Create(aParent: TKMPanel);
var
  I: Integer;
begin
  inherited Create;

  Panel_BlockTrade := TKMPanel.Create(aParent, 9, 28, aParent.Width - 9, 400);
  with TKMLabel.Create(Panel_BlockTrade, 0, PAGE_TITLE_Y, Panel_BlockTrade.Width, 0, gResTexts[TX_MAPED_BLOCK_TRADE], fntOutline, taCenter) do
    Anchors := [anLeft, anTop, anRight];
  for I := 1 to STORE_RES_COUNT do
  begin
    Button_BlockTrade[I] := TKMButtonFlat.Create(Panel_BlockTrade, 9 + ((I-1) mod 5)*37, 30 + ((I-1) div 5)*37,33,33, 0);
    Button_BlockTrade[I].TexID := gResWares[StoreResType[I]].GUIIcon;
    Button_BlockTrade[I].Hint := gResWares[StoreResType[I]].Title;
    Button_BlockTrade[I].OnClickShift := Player_BlockTradeClick;
    Button_BlockTrade[I].Tag := I;
    Image_BlockTrade[I] := TKMImage.Create(Panel_BlockTrade, 9 + ((I-1) mod 5)*37 + 15, 30 + ((I-1) div 5)*37 + 15, 16, 16, 0, rxGuiMain);
    Image_BlockTrade[I].Hitable := False;
    Image_BlockTrade[I].ImageCenter;
  end;
end;


procedure TKMMapEdPlayerBlockTrade.Player_BlockTradeClick(Sender: TObject; Shift: TShiftState);
var
  I: Integer;
  R: TKMWareType;
begin
  I := TKMButtonFlat(Sender).Tag;
  R := StoreResType[I];

  gMySpectator.Hand.Locks.AllowToTrade[R] := not gMySpectator.Hand.Locks.AllowToTrade[R];

  Player_BlockTradeRefresh;
end;


procedure TKMMapEdPlayerBlockTrade.Player_BlockTradeRefresh;
var
  I: Integer;
  R: TKMWareType;
begin
  for I := 1 to STORE_RES_COUNT do
  begin
    R := StoreResType[I];
    if gMySpectator.Hand.Locks.AllowToTrade[R] then
      Image_BlockTrade[I].TexID := 0
    else
      Image_BlockTrade[I].TexID := 32; //Red cross
  end;
end;


procedure TKMMapEdPlayerBlockTrade.Hide;
begin
  Panel_BlockTrade.Hide;
end;


procedure TKMMapEdPlayerBlockTrade.Show;
begin
  Player_BlockTradeRefresh;
  Panel_BlockTrade.Show;
end;


function TKMMapEdPlayerBlockTrade.Visible: Boolean;
begin
  Result := Panel_BlockTrade.Visible;
end;


end.
