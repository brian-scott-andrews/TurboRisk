program PascalScriptReloadTests;

{$MODE Delphi}

uses SysUtils, uPSCompiler, uPSRuntime, uPSUtils;

type
  TTestExec = class(TPSExec)
    procedure CheckClearedContext;
  end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure TTestExec.CheckClearedContext;
begin
  Check(FCurrProc = nil, 'Reload retained a freed current procedure');
  Check(FData = nil, 'Reload retained freed bytecode');
  Check(FDataLength = 0, 'Reload retained bytecode length');
  Check(FCurrentPosition = 0, 'Reload retained bytecode position');
  Check(FCurrStackBase = InvalidVal, 'Reload retained a stack frame');
end;

function CompileScript(Value: Integer): tbtString;
var
  Compiler: TPSPascalCompiler;
begin
  Compiler := TPSPascalCompiler.Create;
  try
    Check(Compiler.Compile(
      'procedure Placement(var Territory: integer); begin Territory := ' +
      IntToStr(Value) + '; end; begin end.'),
      'Could not compile reload regression');
    Check(Compiler.GetOutput(Result), 'Could not obtain compiled regression');
  finally
    Compiler.Free;
  end;
end;

procedure Run;
var
  Exec: TTestExec;
  FirstCode, SecondCode: tbtString;
  Params: TPSList;
  Territory: PPSVariant;
  I, Expected: Integer;
begin
  FirstCode := CompileScript(5);
  SecondCode := CompileScript(17);
  Exec := TTestExec.Create;
  try
    Check(Exec.LoadData(FirstCode), 'Initial script did not load');
    Check(Exec.RunScript, 'Initial main procedure failed');
    Exec.RaiseCurrentException;
    for I := 1 to 100 do begin
      if Odd(I) then begin
        Check(Exec.LoadData(SecondCode), 'Second script did not load');
        Expected := 17;
      end
      else begin
        Check(Exec.LoadData(FirstCode), 'First script did not reload');
        Expected := 5;
      end;
      Exec.CheckClearedContext;
      Params := TPSList.Create;
      Territory := CreateHeapVariant(Exec.FindType2(btS32));
      Check(Territory <> nil, 'Could not allocate territory parameter');
      Params.Add(Territory);
      try
        VSetInt(Territory, 0);
        Check(Exec.RunProc(Params, Exec.GetProc('PLACEMENT')),
          'Placement failed after reload');
        Exec.RaiseCurrentException;
        Check(VGetInt(Territory) = Expected, 'Placement returned wrong territory');
        Check(Exec.RunProc(Params, Exec.GetProc('PLACEMENT')),
          'Repeated placement failed');
        Exec.RaiseCurrentException;
        Check(VGetInt(Territory) = Expected, 'Repeated placement changed result');
      finally
        FreePIFVariantList(Params);
      end;
      Check(Exec.RunScript, 'Reloaded main procedure failed');
      Exec.RaiseCurrentException;
    end;
    Exec.Clear;
    Exec.CheckClearedContext;
    Check(not Exec.LoadData('invalid'), 'Malformed bytecode was accepted');
    Exec.CheckClearedContext;
  finally
    Exec.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('PascalScript reload tests passed');
  except
    on E: Exception do begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
