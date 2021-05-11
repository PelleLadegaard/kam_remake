unit KM_GUIMapEdMenuLoad;
{$I KaM_Remake.inc}
interface
uses
   Classes, SysUtils, Math,
   KM_Controls, KM_Maps, KM_Defaults, KM_MapTypes;

type
  TKMMapEdMenuLoad = class
  private
    fOnDone: TNotifyEvent;

    fMaps: TKMapsCollection;
    fMapsMP: TKMapsCollection;
    fMapsCM: TKMapsCollection;
    fMapsDL: TKMapsCollection;

    procedure Menu_LoadClick(Sender: TObject);
    procedure Menu_LoadChange(Sender: TObject);
    procedure Menu_LoadUpdate;
    procedure Menu_LoadUpdateDone(Sender: TObject);
    procedure UpdateCampaignState;
  protected
    Panel_Load: TKMPanel;
    Radio_Load_MapType: TKMRadioGroup;
    DropBox_Campaigns: TKMDropList;
    ListBox_Load: TKMListBox;
    Button_LoadLoad: TKMButton;
    Button_LoadCancel: TKMButton;
  public
    constructor Create(aParent: TKMPanel; aOnDone: TNotifyEvent);
    destructor Destroy; override;

    procedure SetLoadMode(aMapFolder: TKMapFolder);
    procedure Show;
    procedure Hide;
    procedure UpdateState;
  end;


implementation
uses
  KM_ResTexts, KM_Game, KM_GameApp, KM_RenderUI, KM_ResFonts, KM_InterfaceGame,
  KM_InterfaceMapEditor, KM_Defaults, KM_MapTypes, KM_CommonTypes, KM_Campaigns, KM_GameSettings;


{ TKMMapEdMenuLoad }
constructor TKMMapEdMenuLoad.Create(aParent: TKMPanel; aOnDone: TNotifyEvent);
var
  I: Integer;
begin
  inherited Create;

  fOnDone := aOnDone;

  fMaps := TKMapsCollection.Create(mfSP);
  fMapsMP := TKMapsCollection.Create(mfMP);
  fMapsCM := TKMapsCollection.Create(mfCM);
  fMapsDL := TKMapsCollection.Create(mfDL);

  Panel_Load := TKMPanel.Create(aParent,0,45,aParent.Width,aParent.Height - 45);
  Panel_Load.Anchors := [anLeft, anTop, anBottom];

  with TKMLabel.Create(Panel_Load, 9, PAGE_TITLE_Y, Panel_Load.Width - 9, 30, gResTexts[TX_MAPED_LOAD_TITLE], fntOutline, taLeft) do
    Anchors := [anLeft, anTop, anRight];
  with TKMBevel.Create(Panel_Load, 9, 30, TB_MAP_ED_WIDTH - 9, 82) do
    Anchors := [anLeft, anTop, anRight];
  Radio_Load_MapType := TKMRadioGroup.Create(Panel_Load,13,34,Panel_Load.Width - 9,78,fntGrey);
  Radio_Load_MapType.Anchors := [anLeft, anTop, anRight];
  Radio_Load_MapType.ItemIndex := 0;
  Radio_Load_MapType.Add(gResTexts[TX_MENU_MAPED_SPMAPS]);
  Radio_Load_MapType.Add(gResTexts[TX_MENU_MAPED_MPMAPS_SHORT]);
  Radio_Load_MapType.Add(gResTexts[TX_MENU_CAMPAIGNS]);
  Radio_Load_MapType.Add(gResTexts[TX_MENU_MAPED_DLMAPS]);
  Radio_Load_MapType.OnChange := Menu_LoadChange;

  DropBox_Campaigns := TKMDropList.Create(Panel_Load, 9, 120, Panel_Load.Width - 9, 20, fntMetal, gResTexts[TX_MISSION_DIFFICULTY], bsMenu);

  DropBox_Campaigns.Anchors := [anLeft, anBottom];
  DropBox_Campaigns.OnChange := Menu_LoadChange;
  DropBox_Campaigns.Clear;
  for I := 0 to gGameApp.Campaigns.Count - 1 do
    DropBox_Campaigns.Add(gGameApp.Campaigns[I].GetCampaignTitle);
  DropBox_Campaigns.ItemIndex := gGameSettings.MapEdCMIndex;
  DropBox_Campaigns.Hide;

  ListBox_Load := TKMListBox.Create(Panel_Load, 9, 145, Panel_Load.Width - 9, 175, fntGrey, bsGame);
  ListBox_Load.Anchors := [anLeft, anTop, anRight];
  ListBox_Load.ItemHeight := 18;
  ListBox_Load.AutoHideScrollBar := True;
  ListBox_Load.ShowHintWhenShort := True;
  ListBox_Load.HintBackColor := TKMColor3f.NewB(87, 72, 37);
  ListBox_Load.SearchEnabled := True;
  ListBox_Load.OnDoubleClick := Menu_LoadClick;
  Button_LoadLoad     := TKMButton.Create(Panel_Load,9,335,Panel_Load.Width - 9,30,gResTexts[TX_MAPED_LOAD],bsGame);
  Button_LoadLoad.Anchors := [anLeft, anTop, anRight];
  Button_LoadCancel   := TKMButton.Create(Panel_Load,9,370,Panel_Load.Width - 9,30,gResTexts[TX_MAPED_LOAD_CANCEL],bsGame);
  Button_LoadCancel.Anchors := [anLeft, anTop, anRight];
  Button_LoadLoad.OnClick     := Menu_LoadClick;
  Button_LoadCancel.OnClick   := Menu_LoadClick;

  UpdateCampaignState;
end;


destructor TKMMapEdMenuLoad.Destroy;
begin
  fMaps.Free;
  fMapsMP.Free;
  fMapsCM.Free;
  fMapsDL.Free;

  inherited;
end;

procedure TKMMapEdMenuLoad.UpdateCampaignState;
begin
  DropBox_Campaigns.Visible := Radio_Load_MapType.ItemIndex = 2;
  ListBox_Load.Top := IfThen(Radio_Load_MapType.ItemIndex = 2, 145, 120);
  ListBox_Load.Height := IfThen(Radio_Load_MapType.ItemIndex = 2, 180, 205);
end;


//Mission loading dialog
procedure TKMMapEdMenuLoad.Menu_LoadClick(Sender: TObject);
var
  mapName: string;
  isMulti: Boolean;
begin
  if (Sender = Button_LoadLoad) or (Sender = ListBox_Load) then
  begin
    if ListBox_Load.ItemIndex = -1 then Exit;

    mapName := ListBox_Load.Item[ListBox_Load.ItemIndex];
    isMulti := Radio_Load_MapType.ItemIndex <> 0;
    gGameApp.NewMapEditor(TKMapsCollection.FullPath(mapName, '.dat', TKMapFolder(Radio_Load_MapType.ItemIndex)), isMulti);
  end
  else
  if Sender = Button_LoadCancel then
    fOnDone(Self);
end;


procedure TKMMapEdMenuLoad.Menu_LoadChange(Sender: TObject);
begin
  Menu_LoadUpdate;
end;

procedure TKMMapEdMenuLoad.Menu_LoadUpdate;
begin
  fMaps.TerminateScan;
  fMapsMP.TerminateScan;
  fMapsCM.TerminateScan;
  fMapsDL.TerminateScan;

  ListBox_Load.Clear;
  ListBox_Load.ItemIndex := -1;
  UpdateCampaignState;
  case Radio_Load_MapType.ItemIndex of
    0: fMaps.Refresh(Menu_LoadUpdateDone);
    1: fMapsMP.Refresh(Menu_LoadUpdateDone);
    2: fMapsCM.Refresh(Menu_LoadUpdateDone);
    3: fMapsDL.Refresh(Menu_LoadUpdateDone);
    else Exit;
  end;
end;


procedure TKMMapEdMenuLoad.Menu_LoadUpdateDone(Sender: TObject);
var
  I: Integer;
  prevMap: string;
  prevTop: Integer;
  M: TKMapsCollection;
  Campaign: TKMCampaign;
begin
  case Radio_Load_MapType.ItemIndex of
    0: M := fMaps;
    1: M := fMapsMP;
    2: M := fMapsCM;
    3: M := fMapsDL;
    else Exit;
  end;

  //Remember previous map
  if ListBox_Load.ItemIndex <> -1 then
    prevMap := M.Maps[ListBox_Load.ItemIndex].FileName
  else
    prevMap := '';
  prevTop := ListBox_Load.TopIndex;

  Campaign := nil;
  if (Radio_Load_MapType.ItemIndex = 2) and (DropBox_Campaigns.ItemIndex >= 0) then
    Campaign := gGameApp.Campaigns[DropBox_Campaigns.ItemIndex];

  ListBox_Load.Clear;

  M.Lock;
  try
    for I := 0 to M.Count - 1 do
    begin
      if (Radio_Load_MapType.ItemIndex = 2) and (not Assigned(Campaign) or not CompareCampaignId(M.Maps[I].CampaignId, Campaign.CampaignId)) then
        Continue;

      ListBox_Load.Add(M.Maps[I].FileName, I);
      if M.Maps[I].FileName = prevMap then
        ListBox_Load.ItemIndex := ListBox_Load.Count - 1;
    end;
  finally
    M.Unlock;
  end;

  ListBox_Load.TopIndex := prevTop;
end;


procedure TKMMapEdMenuLoad.Hide;
begin
  fMaps.TerminateScan;
  fMapsMP.TerminateScan;
  fMapsCM.TerminateScan;
  fMapsDL.TerminateScan;
  Panel_Load.Hide;
end;


procedure TKMMapEdMenuLoad.Show;
begin
  Menu_LoadUpdate;
  Panel_Load.Show;
end;


procedure TKMMapEdMenuLoad.UpdateState;
begin
  if fMaps <> nil then fMaps.UpdateState;
  if fMapsMP <> nil then fMapsMP.UpdateState;
  if fMapsCM <> nil then fMapsCM.UpdateState;
  if fMapsDL <> nil then fMapsDL.UpdateState;
end;


procedure TKMMapEdMenuLoad.SetLoadMode(aMapFolder: TKMapFolder);
begin
  Radio_Load_MapType.ItemIndex := Integer(aMapFolder);
  UpdateCampaignState;
end;


end.
