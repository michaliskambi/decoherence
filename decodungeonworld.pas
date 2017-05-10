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

{ contains definitions for most abstract World entity }

unit decodungeonworld;

{$INCLUDE compilerconfig.inc}
interface

uses classes, fgl, castleVectors,
  X3DNodes, CastleScene,
  decodungeongenerator, decoabstractgenerator, deco3dworld,
  decodungeontiles,
  deconavigation, decoglobal;


{list of "normal" tiles}
type TTilesList = specialize TFPGObjectList<DTileMap>;

//type TContainer = TTransformNode;//{$IFDEF UseSwitches}TSwitchNode{$ELSE}TTransformNode{$ENDIF}

type
  {Dungeon world builds and manages any indoor tiled location}
  DDungeonWorld = class(D3dWorld)
  private
    {some ugly fix for coordinate uninitialized at the beginning of the world}
    const UninitializedCoordinate = -1000000;
  private
    px,py,pz,px0,py0,pz0: TIntCoordinate;
    {converts x,y,z to px,py,pz and returns true if changed
     *time-critical procedure}
    function UpdatePlayerCoordinates(x,y,z: float): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
    {Manages tiles (show/hide/trigger events) *time-critical procedure}
    Procedure manage_tiles; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
  protected
    {scale used to define a tile size. Usually 1 is man-height.
      CAUTION this scale must correspond to tiles model scale, otherwise it'll mess everything up}
    WorldScale: float;
    {neighbours array}
    Neighbours: TNeighboursMapArray;
    {List of tile names.
     MAY be freed after loading?}
    TilesList: TStringList;
    {is this one needed? We already have a map}
    Tiles: TTilesList;
    {root nodes of the each tile
     MUST go synchronous with groups/neighbours!}
    Tiles3d: TRootList;
    {sequential set of tiles, to be added to the world during "build"}
    Steps: TGeneratorStepsArray;
    {loads tiles from HDD}
    procedure LoadWorldObjects; override;
    {assembles MapTiles from Tiles 3d, adding transforms nodes according to generator steps}
    procedure BuildTransforms; override;
  public
    {all-purpose map of the current world, also contains minimap image}
    Map: DMap;

    {Detects if the current tile has been changed and launches manage_tiles}
    Procedure manage(position: TVector3Single); override;
    {Sorts tiles into chunks}
    //Procedure chunk_n_slice; override;
    {loads the world from a running generator}
    procedure Load(Generator: DAbstractGenerator); override;
    {loads the world from a saved file}
    procedure Load(URL: string); override;

    {loads word scenes into scene manager}
    Procedure Activate; override;

    constructor create; override;
    destructor destroy; override;
  end;


{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
uses sysutils, CastleFilesUtils,
  CastleSceneCore,
  deco3dload;

procedure DDungeonWorld.manage_tiles; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  {prepare visibe lists,
   we can't assign the values directly, because groups can contain multiple tiles
   and the effect might be overlapping
   there should be no performance/memory issues with two additional local arrays, I hope
   however, some optimization here might come in handy some day}

  //*** IF PX0<0 then...

  //appear list
  //vanish list

  {
  repeat
  {  if old[i].tile = new[i].tile then ;
    else}
    if old[i].tile > new[j].tile then begin
      {there's a new tile to turn on}
      tile[new[j]] := true
      inc(j);
    end else
    if new[i].tile>old[j].tile then begin
    {there's an old tile to turn off}
      tile[old[i].tile] := false;
      inc(i);
    end else begin
      {the tile exists in both new and old neighbours lists, change nothing and advance to the next tile}
      inc(i);
      inc(j);
    end;
  until i>= old.count-1 and j>= new.count-1; {$warning check here}
  {now we actually put the calculated arrays into current 3d world}
  for i := 0 to group.count-1 do group[i] := false;
  for i := 0 to new.count-1 do group...
  }

end;

{----------------------------------------------------------------------------}

function DDungeonWorld.UpdatePlayerCoordinates(x,y,z: float): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
//var nx,ny,nz: TIntCoordinate;
begin
  {todo: may be optimized, at the moment we have here: 6 assignments,
   using nx,ny,nz we will have *MORE* work *IF* the tile has changed,
   but only 3 assignments otherwise}
  px0 := px;
  py0 := py;
  pz0 := pz;
  px := round( x/WorldScale);
  py := round(-y/WorldScale);     //pay attention: y-coordinate is inversed!
  pz := round(-(z-1)/WorldScale); //pay attention: z-coordinate is inversed and shifted!
  if px<0 then px :=0 else if px>map.sizex-1 then px := map.sizex-1;
  if py<0 then py :=0 else if py>map.sizey-1 then py := map.sizey-1;
  if pz<0 then pz :=0 else if pz>map.sizez-1 then pz := map.sizez-1;
  if (px<>px0) or (py<>py0) or (pz<>pz0) then {begin}
    {current tile has changed}
    result := true
  {end}
  else
    {current tile hasn't changed}
    result := false;
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.manage(position: TVector3Single);
begin
  if FirstRender then begin
    {$warning reset all tiles visibility here}
    LastRender := now;
    FirstRender := false;
  end;

  if UpdatePlayerCoordinates(position[0],position[1],position[2]) then manage_tiles;
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.Load(Generator: DAbstractGenerator);
var DG: D3dDungeonGenerator;
begin
  DG := Generator as D3dDungeonGenerator;
  fSeed := drnd.Random32bit; //todo: maybe other algorithm
  Map := DG.ExportMap;
  Groups := DG.ExportGroups;
  Neighbours := DG.ExportNeighbours;
  TilesList := DG.ExportTiles;
  Steps := DG.ExportSteps;
  {$hint WorldScale must support different scales}
  WorldScale := TileScale;
  {yes, we load tiles twice in this case (once in the generator and now here),
   however, loading from generator is *not* a normal case
   (used mostly for testing in pre-alpha), so such redundancy will be ok
   normally World should load from a file and loading tiles will happen only once}
end;


{----------------------------------------------------------------------------}

procedure DDungeonWorld.Load(URL: string);
begin
  {$Warning dummy}
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.LoadWorldObjects;
var s: string;
  tmpMap: DTileMap;
  tmpRoot: TX3DRootNode;
begin
  FreeAndNil(Tiles);
  tiles := TTilesList.create(true);
  tiles3d := TRootList.create(true);
  For s in TilesList do begin
    tmpMap := DTileMap.Load(ApplicationData(TilesFolder+s),true);
    tiles.Add(tmpMap);
    tmpRoot := LoadBlenderX3D(ApplicationData(TilesFolder+s+'.x3d'+GZ_ext));
    tmpRoot.KeepExisting := 1;   //List owns the nodes, so don't free them manually/automatically
    Tiles3d.add(tmpRoot);
  end;
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.Activate;
var
  startx,starty,startz: integer;
begin
  inherited;
  {$HINT navigation set_nav}
  camera.SetView(Vector3Single(0,0,1),Vector3Single(0,1,0),Vector3Single(0,0,1),Vector3Single(0,0,1),true);

  startx := 4;
  starty := 4;
  startz := 0;
  camera.Position := vector3single((startx)*WorldScale,-(starty)*WorldScale,(startz)*WorldScale+PlayerHeight);
  {$WARNING to be managed by the world}
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.buildTransforms;
var i: integer;
  Transform: TTransformNode;
begin
  WorldObjects := TTransformList.create(false); //scene will take care of freeing
  for i := 0 to high(steps) do begin
    Transform := TTransformNode.create;
    //put current tile into the world. Pay attention to y and z coordinate inversion.
    Transform.translation := Vector3Single(WorldScale*(steps[i].x),-WorldScale*(steps[i].y),-WorldScale*(steps[i].z));
    //Transform.scale := Vector3Single(myscale,myscale,myscale);
    AddRecoursive(Transform,Tiles3d[steps[i].tile]);
    WorldObjects.Add(Transform);
  end;
end;

{----------------------------------------------------------------------------}

constructor DDungeonWorld.create;
begin
  inherited;
  px := UninitializedCoordinate;
  py := UninitializedCoordinate;
  pz := UninitializedCoordinate;
  px0 := UninitializedCoordinate;        //we use px0 := px at the moment, so these are not needed, but it might change in future
  py0 := UninitializedCoordinate;
  pz0 := UninitializedCoordinate;
end;

{----------------------------------------------------------------------------}

destructor DDungeonWorld.destroy;
begin
  {$hint freeandnil(window.scenemanager)?}
  
  //free basic map parameters
  freeandnil(map);
  FreeAndNil(groups);
  FreeNeighboursMap(Neighbours);
  FreeAndNil(TilesList);
  
  //free loaded tiles
  FreeAndNil(Tiles);   //owns children, so will free them automatically
  FreeAndNil(Tiles3d); //owns children, so will free them automatically

  inherited;
end;

end.

