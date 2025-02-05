unit KM_UtilsExt;
{$I KaM_Remake.inc}
interface
uses
  Classes,
  Controls
  {$IFDEF MSWindows}
  , Windows
  {$ENDIF}
  {$IFDEF Unix}
  , unix, baseunix, UnixUtil
  {$ENDIF}
  ;

  function GetShiftState(aButton: TMouseButton): TShiftState;
  function GetMultiplicator(aButton: TMouseButton): Word; overload;
  function GetMultiplicator(aShift: TShiftState): Word; overload;


implementation
//uses
//  {$IFDEF FPC} FileUtil, {$ENDIF}
//  {$IFDEF WDC} IOUtils {$ENDIF};


function GetShiftState(aButton: TMouseButton): TShiftState;
begin
  Result := [];
  case aButton of
    mbLeft:   Include(Result, ssLeft);
    mbRight:  Include(Result, ssRight);
  end;

  if GetKeyState(VK_SHIFT) < 0 then
    Include(Result, ssShift);
end;


function GetMultiplicator(aButton: TMouseButton): Word;
begin
  Result := GetMultiplicator(GetShiftState(aButton));
end;


function GetMultiplicator(aShift: TShiftState): Word;
begin
  Exclude(aShift, ssCtrl); //Ignore Ctrl
  Result := Byte(aShift = [ssLeft])
          + Byte(aShift = [ssRight]) * 10
          + Byte(aShift = [ssShift,ssLeft]) * 100
          + Byte(aShift = [ssShift,ssRight]) * 1000;
end;


end.
