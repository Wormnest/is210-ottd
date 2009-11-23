import("pathfinder.road", "RoadPathFinder", 3);

/*
 * 	This file is part of rocketAI.
 *
 *	rocketAI is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	rocketAI is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with rocketAI.  If not, see <http://www.gnu.org/licenses/>.
*/


/*--------------------------------------------------------
|    The main class rocketAI starts about line 250       |
--------------------------------------------------------*/


/*--------------------------------------------------------------------
|                                                                     |
|    Tile                                                             |
|                                                                     |
 --------------------------------------------------------------------*/
class Tile
{
	constructor() {
		
	}
	function GetAdjacentTiles(tile);
	function IsRoadBuildable(tile);  // used for valuator
}	

function Tile::GetAdjacentTiles(tile)
{
	local adjTiles = AITileList();
	
	adjTiles.AddTile(tile - AIMap.GetTileIndex(1,0));
	adjTiles.AddTile(tile - AIMap.GetTileIndex(0,1));
	adjTiles.AddTile(tile - AIMap.GetTileIndex(-1,0));
	adjTiles.AddTile(tile - AIMap.GetTileIndex(0,-1));
	
	return adjTiles;
}

function Tile::IsRoadBuildable(tile)
{
	if (AITile.IsBuildable(tile) || AIRoad.IsRoadTile(tile)) return true;
	return false;
}

/*--------------------------------------------------------------------
|                                                                     |
|    TownManager                                                      |
|                                                                     |
 --------------------------------------------------------------------*/
class TownManager
{
	constructor() {
	}
	function BuildBusStop(tile);
	function BuildDepot(tile);
	function FindLineBusStopLocation(town, pass_cargo_id, estimate);
}


/*------------------------------------------------------------------*/
function TownManager::FindLineBusStopLocation(town, pass_cargo_id, estimate)
{
	local tl = AITileList();
	local aitile = null;
	local tile = AITown.GetLocation(town);
	local found = false;
	local ret_tile = null;
	
	tl.AddRectangle(tile + AIMap.GetTileIndex(-10, -10), tile + AIMap.GetTileIndex(10, 10));
	
	/* remove all tiles that are already covered by a station */
	local tl2 = AITileList();

	tl2.AddList(tl);
	tl2.Valuate(AIRoad.IsRoadStationTile);
	tl2.KeepValue(1);

	for (local rstl = tl2.Begin(); tl2.HasNext() ; rstl = tl2.Next()){
		/* Keep our own stations a bit apart */
		if (AITile.GetOwner(rstl) == AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)) {
			tl.RemoveRectangle(rstl + AIMap.GetTileIndex(-4, -4), rstl + AIMap.GetTileIndex(4, 4));
		}
		else {    /* but don't be so modest with other players stations ... */
			tl.RemoveRectangle(rstl + AIMap.GetTileIndex(-1, -1), rstl + AIMap.GetTileIndex(1, 1));
		}
	}	 

	if (tl.Count()) {
		/* find all tiles that are next to a road tile */
		tl.Valuate(AIRoad.GetNeighbourRoadCount);	
		tl.KeepAboveValue(0);

		if (tl.Count()) {
			/* find all tiles that are not road */
	   	tl.Valuate(AIRoad.IsRoadTile);	
   	  	tl.KeepValue(0);
			if (tl.Count()) {
	   		/* find all tiles that are not sloped */
		   	tl.Valuate(AITile.GetSlope);	
   		   tl.KeepValue(0);
				if (tl.Count()) {
					tl.Valuate(AITile.GetCargoAcceptance, pass_cargo_id,
								 1, 1, 
								 AIStation.GetCoverageRadius (AIStation.STATION_BUS_STOP));
					for (aitile = tl.Begin(); tl.HasNext(); aitile = tl.Next()){
//						AISign.BuildSign(aitile,"ex"+tl.GetValue(aitile));
						if (tl.GetValue(aitile) >= 15){
  							found = AITile.IsBuildable(aitile);
							if (estimate) {
								found = true;
							}	
							if (!found)	{
								found = AITile.DemolishTile(aitile);
							}
							if (found) {
								ret_tile = aitile;
								break;
							}	
						}	
//						else {
//							AILog.Info("Find busstop location, acceptance too low " + tl.GetValue(aitile));
//						}
	   			}
				}
				else {
					AILog.Info("Find busstop location, no unsloped tiles present");
				}
	   	}
			else {
				AILog.Info("Find busstop location, no tiles that are not road present");
			}
	   }
		else {
			AILog.Info("Find busstop location, no tiles next to road present");
		}
	}
	

	
	if (found) {
//		AISign.BuildSign(aitile,"ex"+tl.GetValue(aitile));
		return ret_tile;	
	}	
	else {
		return null;	
	}	
}

/*------------------------------------------------------------------*/
function TownManager::BuildDepot(tile)
{
	local found = false;
	local success = false;

	local adjacentTiles = Tile.GetAdjacentTiles(tile);

	for(local tile2 = adjacentTiles.Begin(); 
			adjacentTiles.HasNext() && !found; 
			tile2 = adjacentTiles.Next()) {
		if(AIRoad.IsRoadTile(tile2) ) {
			success = true;
			//local bbpf = PathFinder();
			local count = 0;
			while(!success && (count < 100)){
				local pathlen = AIRoad.BuildRoad(tile2, tile);
//				AILog.Info("Build busstop pathlen " + pathlen);
				if (pathlen == 2) {
					success = true; 
				} else {
					count = count + 1;
				}
			}
			local truck = AIRoad.ROADVEHTYPE_BUS; 
			local adjacent = AIStation.STATION_NEW;
			if (success) {
				AITile.DemolishTile(tile);
				// AITile.DemolishTile(tile2);
				AIRoad.BuildRoad(tile2, tile);
				success = AIRoad.BuildRoadDepot(tile, tile2);
			}
			found = true;
		}
	}

	if (!success) {
		AILog.Info("Build depot failed "+ AIError.GetLastErrorString());
//		AISign.BuildSign(tile,"bbs");
	}
	return tile;	
}



/*------------------------------------------------------------------*/
function TownManager::BuildBusStop(tile)
{
	local found = false;
	local success = false;

	local adjacentTiles = Tile.GetAdjacentTiles(tile);

	for(local tile2 = adjacentTiles.Begin(); 
			adjacentTiles.HasNext() && !found; 
			tile2 = adjacentTiles.Next()) {
		if(AIRoad.IsRoadTile(tile2) ) {
			success = true;
			//local bbpf = PathFinder();
			local count = 0;
			while(!success && (count < 100)){
				local pathlen = AIRoad.BuildRoad(tile2, tile);
//				AILog.Info("Build busstop pathlen " + pathlen);
				if (pathlen == 2) {
					success = true; 
				} else {
					count = count + 1;
				}
			}
			local truck = AIRoad.ROADVEHTYPE_BUS; 
			local adjacent = AIStation.STATION_NEW;
			if (success) {
				AITile.DemolishTile(tile);
				// AITile.DemolishTile(tile2);
				AIRoad.BuildRoad(tile2, tile);
				success = AIRoad.BuildRoadStation(tile, tile2, truck, adjacent);
			}
			found = true;
		}
	}

	if (!success) {
		AILog.Info("Build busstop failed "+ AIError.GetLastErrorString());
//		AISign.BuildSign(tile,"bbs");
	}
	return tile;	
}



/*--------------------------------------------------------------------
|                                                                     |
|    rocketAI                                                         |
|                                                                     |
 --------------------------------------------------------------------*/

 
class rocketAI extends AIController {
	passenger_cargo_id = 0;
}

/*------------------------------------------------------------------|
|	ManageLoan is used to pay back money when finished building		|
-------------------------------------------------------------------*/

function rocketAI::ManageLoan()
{
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local loan = AICompany.GetLoanAmount();
	local pay_back_balance =  2 * AICompany.GetLoanInterval(); 
	local loan_interval = AICompany.GetLoanInterval();
	local pay_back = 0;
	
	while(( balance - pay_back >= pay_back_balance) 
			&& (loan - pay_back > 0))	{
		pay_back += loan_interval;
	}
	if (pay_back) {
		if(!AICompany.SetLoanAmount(loan - pay_back))	{
			AILog.Info(AICompany.GetName() + " Failed to pay back");
		}
//		else {
//			AILog.Info("Paid back: " + pay_back);
//		}
	}	
//	AILog.Info("Loan: " + AICompany.GetLoanAmount());
}
 
 
 
function rocketAI::Start()
{
	AILog.Info("Loans max amount to be able to build roads and busses");
	AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
	local bus_model = 0;
	local build = 0;
	local depot = 0;
	local station_a = 0;
	local station_b = 0;
	
	
	/* Get a list of all towns on the map. */
	local townlist = AITownList();
	/* Sort the list by population, highest population first. */
	townlist.Valuate(AITown.GetPopulation);
	townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
	/* Pick the two towns with the highest population. */
	local townid_a = townlist.Begin();
	local teller = 1;
	
	/* Makes a list of different bus types so the AI knows which bus to build */
	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);
	
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	engine_list.Valuate(AIEngine.GetPrice);
	engine_list.KeepBelowValue(balance);

	engine_list.Valuate(AIEngine.GetCargoType)
	engine_list.KeepValue(passenger_cargo_id); 

	engine_list.Valuate(AIEngine.GetCapacity)
	engine_list.KeepTop(1);

	bus_model = engine_list.Begin();
	
	
	/*---------------------------------------------------------------------------------|
	|	Builds road from the largest city to the next 5 cities on the list.			   |
	|	Makes a depot in the largest cities and a bus stop in every city.			   |
	|	Builds 5 buses to transport passengers to and from the largest city 		   |
	|	to each of the 5 other cities												   |
	----------------------------------------------------------------------------------*/
	
	for( local k = 1; k<=5; k++ ) {
		local townid_b = townlist.Next();
		/* Print the names of the towns we'll try to connect. */
		AILog.Info("Going to connect " + AITown.GetName(townid_a) + " to " + AITown.GetName(townid_b));
		/* Tell OpenTTD we want to build normal road. */
		AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
		/* Create an instance of the pathfinder. */
		local pathfinder = RoadPathFinder();
		pathfinder.cost.turn = 1;
		/* Give the source and goal tiles to the pathfinder. */
		pathfinder.InitializePath([AITown.GetLocation(townid_a)], [AITown.GetLocation(townid_b)]);
		
		/* Try to find a path. */
		local path = false;
		while (path == false) {
			path = pathfinder.FindPath(100);
			this.Sleep(1);
		}
		
		if (path == null) {
			/* No path was found. */
			AILog.Error("pathfinder.FindPath return null");
		}
		
		/* If a path was found, build a road over it. */
		while (path != null) {
			local par = path.GetParent();
			if (par != null) {
				local last_node = path.GetTile();
				if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
					if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
						/* An error occured while building a piece of road. TODO: handle it.
						* Note that is can also be the case that the road was already build. */
					}
				}
				else {
				/* Build a bridge or tunnel. */
					if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
						/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
						if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
						if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
							if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
								/* An error occured while building a tunnel. TODO: handle it. */
							}
						} 
						else {
							local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
							bridge_list.Valuate(AIBridge.GetMaxSpeed);
							bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
							if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
								/* An error occured while building a bridge. TODO: handle it. */
							}
						}
					}
				}
			}
			path = par;
		}
		AILog.Info(AITown.GetName(townid_a) + " is connected to " + AITown.GetName(townid_b));
		
		if (teller == 1) {
		/* In the largest city we make both a bus depot and a bus stop */
		station_a = TownManager.BuildBusStop(TownManager.FindLineBusStopLocation(townid_a, passenger_cargo_id, true));
		depot = TownManager.BuildDepot(TownManager.FindLineBusStopLocation(townid_a, passenger_cargo_id, true));
		}
		
		/* For every other city we create a bus stop */
		local station_b = TownManager.BuildBusStop(TownManager.FindLineBusStopLocation(townid_b, passenger_cargo_id, true));
		
		/* We create 5 buses for every bus line */
		for (local x = 1; x<=5; x++ ) {
			local build = AIVehicle.BuildVehicle(depot, bus_model);
			AIOrder.AppendOrder(build, depot, AIOrder.AIOF_SERVICE_IF_NEEDED);
			AIOrder.AppendOrder(build, station_a, AIOrder.AIOF_NONE); 
			AIOrder.AppendOrder(build, station_b, AIOrder.AIOF_NONE);
			AIVehicle.StartStopVehicle(build);
		}
		
		teller++;
	}
	AILog.Info("Finished making roads, depot, bus stops and buses. Will pay back loan.");
	ManageLoan();
}

/*------------------------------------------------------------------*/
/*	Just a dummy, to prevent warnings						 		*/ 	
/*------------------------------------------------------------------*/
function rocketAI::Save()
{
	local table = {dummy = false};
	return table;
}

/*------------------------------------------------------------------*/
function rocketAI::Load(version, data)
{
  
}