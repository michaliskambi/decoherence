{Copyright (C) 2012-2017 Yevhen Loza

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.}

{---------------------------------------------------------------------------}

{ Editor for loadscreens: facts and images }
unit constructor_facts;

{$INCLUDE compilerconfig.inc}
interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, CheckLst, Buttons,
  decoloadscreen, decotranslation,
  constructor_global;

type
  {Form to edit facts and corresponding loadscreen images}
  TFactsEditor = class(TWriterForm)
    DeselectAllButton: TButton;
    FactLengthLabel: TLabel;
    SelectAllButton: TButton;
    LoadScreensListBox: TCheckListBox;
    FactsListbox: TListBox;
    Memo1: TMemo;
    procedure DeselectAllButtonClick(Sender: TObject);
    procedure FactsListboxSelectionChange(Sender: TObject; User: boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Memo1Change(Sender: TObject);
    procedure SelectAllButtonClick(Sender: TObject);
  public
    {lists of facts in all available languages.
     If file not found then the value is nil}
    Facts: array [TLanguage] of TFactList;
    {list of all available image files in LoadScreen directory}
    LoadImages: TLoadImageList;
    {re-fills listboxes}
    procedure ReloadContent;
  public
    procedure LoadMe; override;
    procedure FreeMe; override;
    procedure WriteMe(ToGameFolder: boolean); override;
  end;

var
  FactsEditor: TFactsEditor;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
{$R *.lfm}

uses DOM, {$IFDEF gzipdata}CastleDownload,{$ENDIF} CastleXMLUtils,
  CastleLog, decoglobal;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.LoadMe;
var
    CurrentFile: string;
    L: TLanguage;
    LI: DLoadImage;
    Rec: TSearchRec;
    {LI2: DLoadImage;
    F: DFact;}
begin
  for L in TLanguage do begin
    FreeAndNil(Facts[L]);

    try
      CurrentFile := ConstructorData(ScenarioFolder+LanguageDir(L)+'facts.xml',false);
      LoadFacts(CurrentFile);
      Facts[L] := decoloadscreen.Facts;
      decoloadscreen.Facts := nil;
    except
      freeandnil(decoloadscreen.Facts);
      writeLnLog('TFactsEditor.LoadMe','Exception reading '+CurrentFile);
    end;
  end;

  {load directly from the game data folder and not save anywhere intermediately.
   Maybe, this'll need "add an image from this computer" button/feature}
  LoadScreensListBox.clear;
  LoadImages := TLoadImageList.create(true);
  if FindFirst (FakeApplicationData(LoadScreenFolder + '*.jpg'), faAnyFile - faDirectory, Rec) = 0 then begin
    try
      repeat
        LI := DLoadImage.create;
        LI.value := Rec.Name;
        LoadImages.Add(LI);
      until FindNext(Rec) <> 0;
    finally
      FindClose(Rec);
    end;
    WriteLnLog('TFactsEditor.LoadMe','Images loaded = '+inttostr(LoadImages.count));
  end
  else
    WriteLnLog('TFactsEditor.LoadMe','ERROR: Unable to load LoadScreen images');


  {for L in TLanguage do if Facts[L]<>nil then
    for F in Facts[L] do
      For LI in LoadImages do begin
        LI2 := DLoadImage.Create;
        LI2.value := LI.value;
        F.compatibility.add(LI2);
      end;}

  MyLanguage := ConstructorLanguage;    (*not sure about it*)
  isLoaded := true;
  isChanged := false;

  ReloadContent;
end;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.ReloadContent;
var F: DFact;
    LI: DLoadImage;
begin
  memo1.clear;
  FactsListbox.Clear;
  for f in Facts[MyLanguage] do
    FactsListbox.Items.Add(F.value);
  LoadScreensListBox.Clear;
  for LI in LoadImages do
    LoadScreensListBox.Items.add(LI.value);
end;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.WriteMe(ToGameFolder: boolean);
var XMLdoc: TXMLDocument;
    RootNode, ContainerNode, valueNode, value2node, TextNode: TDOMNode;
    i: DFact;
    j: DLoadImage;
    L: TLanguage;
begin
  for L in TLanguage do if Facts[L] = nil then
    WriteLnLog('TFactsEditor.WriteMe','LANGUAGE IS NIL!')
  else begin
    XMLdoc := TXMLDocument.Create;
    RootNode := XMLdoc.CreateElement('FactsList');
    XMLdoc.Appendchild(RootNode);

    for i in Facts[L] do begin
      ContainerNode := XMLdoc.CreateElement('Fact');
      ValueNode := XMLdoc.CreateElement('Value');
      TextNode := XMLdoc.CreateTextNode(UTF8decode(i.value));
      ValueNode.AppendChild(TextNode);
      ContainerNode.AppendChild(ValueNode);
      ValueNode := XMLdoc.CreateElement('ImageList');
      for j in i.compatibility do begin
        Value2Node := XMLdoc.CreateElement('Image');
        TextNode := XMLdoc.CreateTextNode(UTF8decode(j.value));
        Value2Node.AppendChild(TextNode);
        ValueNode.AppendChild(Value2Node);
      end;
      ContainerNode.AppendChild(ValueNode);
      RootNode.Appendchild(ContainerNode);
    end;

    if ToGameFolder then
      URLWriteXML(XMLdoc, ConstructorData(ScenarioFolder+LanguageDir(ConstructorLanguage)+'facts'+XML_extension,ToGameFolder){$IFDEF gzipdata},[ssoGzip]{$ENDIF})
    else
      URLWriteXML(XMLdoc, ConstructorData(ScenarioFolder+LanguageDir(ConstructorLanguage)+'facts.xml',ToGameFolder));

    FreeAndNil(XMLdoc);
  end;
end;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.FormShow(Sender: TObject);
begin
  if (not isLoaded) {or (MyLanguage<>ConstructorLanguage)} then LoadMe;
end;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.Memo1Change(Sender: TObject);
begin
  if length(memo1.Text)<=350 then FactLengthLabel.Color := clDefault
  else FactLengthLabel.Color := clRed;
  FactLengthLabel.caption := 'Total symbol: '+inttostr(length(memo1.Text));
end;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.SelectAllButtonClick(Sender: TObject);
begin
  LoadScreensListBox.CheckAll(cbChecked);
end;
procedure TFactsEditor.DeselectAllButtonClick(Sender: TObject);
begin
  LoadScreensListBox.CheckAll(cbUnchecked);
end;

{-----------------------------------------------------------------------------}

procedure TFactsEditor.FormDestroy(Sender: TObject);
begin
  FreeMe;
end;

{----------------------------------------------------------------------------}

procedure TFactsEditor.FreeMe;
var L: TLanguage;
begin
  for L in TLanguage do
    FreeAndNil(Facts[L]);
  freeAndNil(LoadImages);
end;

{----------------------------------------------------------------------------}

procedure TFactsEditor.FactsListboxSelectionChange(Sender: TObject;
  User: boolean);
begin
  memo1.clear;
  memo1.Lines.add( FactsListBox.Items[FactsListBox.ItemIndex] ); //TODO: read-only atm.
  //compatibility
end;



end.
