pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--tiny sim 0.60
--@yellowbaron, 3d engine @freds72

--scenarios (name,lat,lon,hdg,alt,pitch,bank,throttle,gps dto,nav1,nav2)
local scenarios={
	{"visual approach",-417,326.3,85,600,-1,0,25,3,2,1},
 {"final approach",-408.89,230.77,85,1000,1,0,75,3,2,1},
 {"full approach",-222.22,461.54,313,3000,0,0,91,3,2,1},
 {"engine failure!",-244.44,261.54,50,3500,0,0,0,4,2,5},
 {"unusual attitude",-222.22,461.54,330,450,99,99,100,3,2,1}}

--weather (name,wind,ceiling)
local wx={
	{"clear, calm",{0,0},20000},
 {"clouds, breezy",{60,10},500},
 {"low clouds, stormy",{10,45},200}}

--airport and navaid database (rwy hdg < 180)
local db={
	{-251.11,430.77,"pco","vor"},
 {-422.2,370,"itn","ils",85},
 {-422.2,384.6,"tny","apt",85},
 {-66.67,153.85,"smv","apt",40},
 {-177.78,246.15,"wee","vor"}}

--general settings and vars
palt(15,true)
palt(0,false)
local frame=0

-- plane pos/orientation
local lat,lon,heading,pitch,bank

--instruments
--ai
local aic={64,71} --center
local ai={{-87,72},{215,72},{64,-79},{64,223}}
local aipitch={60,141}
local aistep=10
local aiwidth=8

--hsi
local hsic={64,111} --center
local bp={{{64,98},{64,102},{62,100},{66,100},{64,120},{64,124}},
    {{1,2},{1,3},{1,4},{5,6}}} --bearing pointer
local nesw={{64,99,52},{52,111,53},{64,123,36},{76,111,37}} --cardinal directions
local cdii={{{64,98},{64,102},{62,100},{66,100},{64,120},{64,124},{64,104},{64,118}},
    {{1,2},{1,3},{1,4},{5,6},{7,8}}} --cdi

--inset map
local mapc={22,111} --center
local mapclr={apt=14,vor=12,ils=0}

--3d
-- world axis
local v_fwd,v_right,v_up={0,0,1},{1,0,0},{0,1,0}

-- meter to world scale
local m_scale=0.0202

-- models & actors
local all_models={
	runway={
		c=6,
		v={
		 {15,0,0}, --points
			{15,0,-1500},
			{-15,0,0},
			{-15,0,-1500},
			{20,0,-1500},
			{-20,0,-1500},
			{15,0,-1550},
			{-15,0,-1550},
			{0,0,-1500},
			{0,0,-1600},	
			{-2,0,-1600},
			{-2,0,-1800},	
			{2,0,-1600},
			{2,0,-1800},
			-- central line
			{0,0,0},
			{0,0,-1500},
			-- landing lights
			{-5,0,-1550},
			{5,0,-1550},	
			{-8,0,-1600},
			{8,0,-1600},
			{-10,0,-1700},
			{10,0,-1700},
			{-20,0,-1800},
			{20,0,-1800},
			},
		e={
			{1,2,1}, -- lines + color + number of lights (optional = solid line)
			{3,4,1}, -- note: lines are draw in declared order (allow for lines + lights)
			{1,2,7,128},
			{3,4,7,128},
			{1,3,8,10},
			{5,6,11,20},
		 {2,7,8,5},
		 {4,8,8,5},
		 {9,10,10,10},
		 {11,12,10,10},
		 {13,14,10,10},
		 {15,16,6,128},
		 {17,18,7,8},
		 {19,20,7,8},
		 {21,22,7,10},
		 {23,24,7,10},
		}
	}
}
local actors={}
local all_actors={
	runway={
		model="runway"
  }
}

function _init()
 menu=1
 item=0
 scen=1
 wnd=1
 --
 rpm=2200
 tas=112
 vs=0
 aoa=0
 timer=0
 flps=0
 blag=0 --bank lag
 plag=0 --pitch lag
 slag=0 --stall lag
 --
 brg={}
 dist={}
 crs=0
 cdi=0
 --
 rec,t=0,0
	onground=false
	hardlanding=0 --0: soft, 1: hard, 2:crash
 flight={}

 --3d
 cam=make_cam(64,12,64)

 --
 actors={}
	add(actors,make_actor(all_actors.runway,{-422.2,0,384.6},85/360)) -- tny

	--[[
	add(actors,make_actor(all_actors.runway,{-422.2,0,384.6},85/360)) -- tny
  add(actors,make_actor(all_actors.papi,{-412.2,0,345.6}))
	add(actors,make_actor(all_actors.papi,{-412.2,0,346.6}))
  add(actors,make_actor(all_actors.papi,{-412.2,0,347.6}))
  ]]
	add(actors,make_actor(all_actors.runway,{-66.7,0,153.8},40/360)) -- smv
end

function scenario(s)
  name=scenarios[s][1]
  lat=scenarios[s][2]
  lon=scenarios[s][3]
  heading=scenarios[s][4]
  alt=scenarios[s][5]
  pitch=scenarios[s][6]
  bank=scenarios[s][7]
  throttle=scenarios[s][8]
  dto=scenarios[s][9]
  nav1=scenarios[s][10]
  nav2=scenarios[s][11]
  wind=wx[wnd][2]
  ceiling=wx[wnd][3]
  if(pitch==99) bank,pitch=unusual()
end

function unusual()
  local sign=rnd()<0.5 and 1 or -1
  local bank=(80-rnd(15))*sign
  local pitch=-45
  return bank,pitch
end

function setrpm()
  --set throttle
  if btn(5) then --x
    throttle+=1.5
    blag=-3
  elseif btn(4) then --y
    throttle-=1.5
    blag=3
  end
  throttle=mid(throttle,0,100)
  --calculate rpm
  maxrpm=2400
  if(alt>=2000) maxrpm=2456-0.028*alt
  targetrpm=throttle/100*(maxrpm-700)+700
  rpm+=(targetrpm-rpm)/20
  if(abs(targetrpm-rpm)>=30) plag=(targetrpm-rpm)/20
  rpm=max(rpm,700)
end

function disprpm()
  local drpm,c=flr(rpm/10+0.5)*10
  if drpm<=2000 then c=7 --white
  elseif drpm<=2400 then c=11 --green
  end
  if drpm>=1000 then
    print(sub(drpm,1,2),1,116,c)
    print(sub(drpm,3,4),1,122,c)
  else
    print(sub(drpm,1,1),5,116,c)
    print(sub(drpm,2,3),1,122,c)
  end
  spr(4,1,108-throttle/5)
end

function movepitch()
  if btn(2) then --pitch dn
    plag=max(plag-2,-60)
    pitch-=0.25*cos(bank/360)
  elseif btn(3) and aoa<18 then --pitch up
    plag=min(plag+2,60)
    pitch+=0.35*cos(bank/360)
  elseif plag!=0 then
    pitch+=0.004*plag*cos(bank/360)
    plag-=plag/abs(plag)
  end
  if(abs(pitch)>=45) pitch*=45/abs(pitch)
		if alt==0 then pitch=max(pitch,0) end
end

function movebank()
  if btn(0) then
    blag=max(blag-1,-50)
    bank-=1.8-tas/250
  elseif btn(1) then
    blag=min(blag+1,50)
    bank+=1.8-tas/250
  elseif blag!=0 then
    bank+=0.03*blag
    blag-=blag/abs(blag)
  end
  if (abs(bank)<4 and blag==0) bank/=1.1 --bank stability
  if(abs(bank)>20) pitch-=0.3*abs(sin(bank/360))
  if(abs(bank)>160) pitch-=0.15
  if(bank>180) bank-=360
  if(bank<-180) bank+=360
		if(alt==0) bank/=1.3
end

function dispai()
  ai[1][2]=72+pitch
  ai[2][2]=72+pitch
  ai[3][2]=-80+pitch
  ai[4][2]=222+pitch
  local ax,ay=rotatepoint(ai[1],aic,-bank)
  local bx,by=rotatepoint(ai[2],aic,-bank)
  local cx,cy=rotatepoint(ai[3],aic,-bank)
  local dx,dy=rotatepoint(ai[4],aic,-bank)
  clip(10,36,118,96)
  trifill(ax,ay,bx,by,cx,cy,12)
  trifill(ax,ay,bx,by,dx,dy,4)
  clip(35,44,55,43)
  for j=0,15 do
    local tmp=aipitch[2]-j*aistep+pitch
    local x1,y1=rotatepoint({aipitch[1],tmp},aic,-bank)
    local x2,y2=rotatepoint({aipitch[1]+aiwidth,tmp},aic,-bank)
    if(j!=7) line(x1,y1,x2,y2,7)
  end
  warn(-8,3)
  warn(110,3)
  clip()
  --transparency
  transrect(21,50,33,90)
  transrect(95,50,111,90)
  rectfill(0,33,127,42,6)
  rectfill(0,33,9,127)
  rectfill(0,0,127,25,0)
  line(48,75,aic[1],aic[2],10) --aircraft symbol
  line(80,75,aic[1],aic[2])
end

-- todo: optimize
function transrect(x1,y1,x2,y2)
 for x=x1,x2 do
    for y=y1,y2 do
      local c=pget(x,y)
      if(c==4) pset(x,y,5)
      if(c==12) pset(x,y,13)
    end
  end
end

function warn(y,j)
  for i=0,j do
    local _y=y+i*aistep+pitch
    local j=1
    if(y>64) j=-1
    local x1,y1=rotatepoint({aipitch[1],_y},aic,-bank)
    local x2,y2=rotatepoint({aipitch[1]+aiwidth/2,_y+(aistep-2)*j},aic,-bank)
    local x3,y3=rotatepoint({aipitch[1]+aiwidth,_y},aic,-bank)
    line(x1,y1,x2,y2,8)
    line(x3,y3,x2,y2)
  end
end

function calcalt()
  local coeff=88
  if(vs<0) coeff=74
  vs=tas*-(sin((pitch-aoa)/360))*coeff
		if alt==0 then vs=max(vs,0) end
  alt+=vs/1800
		alt=max(alt,0)
end

function dispalt()
  rectfill(95,68,111,74,0)
  rectfill(103,65,111,77)
  local _y=alt/10
  local y=_y-flr(_y/10)*10
  local y2=flr(y+0.5)
  local y3=((y-0.5)*7)%7
  clip(104,65,7,13)
  print((y2%10)..0,104,66+y3,7)
  print(((y2-1)%10)..0,104,72+y3)
  print(((y2+1)%10)..0,104,60+y3)
  clip()
  local z
  if alt>=9995 then
    rectfill(91,68,94,74,0)
    z=92
  elseif alt<995 then
    z=100
  else
    z=96
  end
  print(flr((_y+0.5)/10),z,69,7)
end

function dispvs()
  local vsoffset=flr(vs/100+0.5)
  vsoffset=mid(vsoffset,-19,21)
  rectfill(115,68-vsoffset,126,74-vsoffset,0)
  spr(23,112,68-vsoffset)
  if(vsoffset!=0) print(flr(vs/100+0.5),115,69-vsoffset,7)
end

function calcheading()
  if abs(bank)<=90 then heading+=bank*0.007
  else heading+=(180-abs(bank))*bank/abs(bank)*0.007 end
  heading=(heading+360)%360
end

function dispheading()
 local hdg=flr(heading+0.5)%360
 if hdg<10 then print("00"..hdg,58,89,7)
 elseif hdg<100 then print("0"..hdg,58,89,7)
 else print(hdg,58,89,7) end
end

function calcspeed()
  local targetspeed=38.67+rpm/30-3.8*pitch --3.6
  targetspeed=mid(targetspeed,-30,200)
  if(flps==1) targetspeed-=10
		if(alt==0) targetspeed-=40
  tas+=(targetspeed-tas)/250
  ias=tas/(1+alt/1000*0.02) --2% per 1000 ft
end

function dispspeed()
  -- red or black
  local c=ias>=163 and 8 or 0
  rectfill(21,68,33,74,c)
  rectfill(29,65,33,77)
  local y=ias-flr(ias/10)*10
  local y2=flr(y+0.5)
  local y3=((y-0.5)*7)%7
  clip(30,65,3,13)
  print(y2%10,30,66+y3,7)
  print((y2-1)%10,30,72+y3)
  print((y2+1)%10,30,60+y3)
  clip()
  local z=ias>=99.5 and 22 or 26
  print(flr((ias+0.5)/10),z,69)
  print(groundspeed,116,37,14)
end

function calcaoa()
  if ias>=71.1 then
    aoa=13.2-0.12*ias
  elseif ias>=46.7 then
    aoa=26-0.3*ias
  else
    aoa=54-0.9*ias
  end
  aoa=max(aoa)
end

function calcposition()
   local dx,dy=-groundspeed*sin(track/360)/2880,groundspeed*cos(track/360)/2880
   lon+=dx
   lat-=dy
end

function disptime()
  timer+=1/30
  local minutes=flr(timer/60)
  local seconds=flr(timer-minutes*60)
  if(minutes<10) minutes="0"..minutes
  if(seconds<10) seconds="0"..seconds
  print(minutes..":"..seconds,108,122)
end

function dispmap()
  --based on 5nm/187.5 per 22px
  latmin=lat+67.77
  lonmin=lon-93.75 --187.5/2
  for l in all(db) do
				local p=disppoint(l)
    if(checkonmap(p)) pset(p[1]+0.5,p[2],mapclr[l[4]]) --x+0.5 necessary?
  end
  spr(33,20,110) --map plane symbol
end

function disppoint(p)
  local mapx=11+22/187.5*(p[2]-lonmin) --scale to map
  local mapy=119-22/187.5*(-p[1]+latmin)
  local rotx,roty=rotatepoint({mapx,mapy},mapc,360-heading)
  return {rotx,roty}
end

function checkonmap(p)
  return p[1]>11 and p[1]<33 and p[2]>97 and p[2]<120
end

function calcdistbrg()
  local j=1
  for l in all(db) do
    dy=-(l[1]-lat)*16/600
    dx=(l[2]-lon)*16/600
    brg[j]=atan2(dx,dy)
    brg[j]=90+(brg[j]*360)-heading
    brg[j]-=flr(brg[j]/360)*360
    dist[j]=sqrt(dx^2+dy^2)
    j+=1
  end
end

function disphsi()
  --transparency
  --todo: optimize, eats 20% cpu
  local aimatrix={}
  for j=49,79 do
    for k=96,126 do
      add(aimatrix,{j,k,pget(j,k)})
    end
  end
  circfill(64,111,15,5)
  for l in all(aimatrix) do
    local c=pget(l[1],l[2])
    if(c==5) pset(l[1],l[2],l[3]+1)
  end
  circ(64,111,8,7)
  spr(19,62,95) --tick mark
  --cardinal directions
  for l in all(nesw) do
    local x,y=rotatepoint(l,hsic,-heading)
    spr(l[3],x-1,y-1)
  end
  --bearing pointer
  for l in all(bp[2]) do
    local x1,y1=rotatepoint(bp[1][l[1]],hsic,brg[nav2])
    local x2,y2=rotatepoint(bp[1][l[2]],hsic,brg[nav2])
    line(x1,y1,x2,y2,12)
  end
  --cdi
  crs=db[nav1][5]-heading
  cdii[1][7][1]=cdi+64
  cdii[1][8][1]=cdi+64
  for l in all(cdii[2]) do
    local x1,y1=rotatepoint(cdii[1][l[1]],hsic,crs)
    local x2,y2=rotatepoint(cdii[1][l[2]],hsic,crs)
    line(x1,y1,x2,y2,11)
  end
  spr(33,62,110) --heading plane symbol
end

function rotatepoint(p,c,angle)
  local x,y=p[1]-c[1],p[2]-c[2]
  local cs,ss=cos(angle/360),sin(angle/360)
  return x*cs+y*ss+c[1],-x*ss+y*cs+c[2]
end

function dispdist(j,x,y,c)
  if dist[j]<10 then
    print(flr(dist[j]*10)/10,x,y,c)
  else
    print(flr(dist[j]),x,y,c)
  end
end

function dispnav()
  print(db[nav1][3],28,37,11)
  print("d",48,37,14) --dto symbol
  print(db[dto][3],56,37)
  print(db[nav2][3],89,122,12)
  dispdist(nav2,89,116,7)
  dispdist(dto,88,37,14)
end

function stall()
  local critical=18+4*flps
  if aoa>=critical then
    slag=45
    plag=0
    if(alt>0) blag=-10
  end
  if alt>0 then
			 pitch-=slag*0.008
		else
			 pitch-=slag*0.003
		end
  if (slag>=1) slag-=1
end

function calcgs() --glideslope
  local alpha=atan2(alt/6072,dist[nav1])*360-270
  gsy=mid(63+10/0.7*(alpha-3),50,74)
end

function dispgs() --glideslope
  if dist[nav1]<15 and alt< 9995 then
    transrect(91,58,93,84)
    for j=0,4 do pset(92,61+j*5,7) end
    line(91,71,93,71,7)
    spr(38,91,gsy+8)
  end
end

function calccdi()
  local cdangle=brg[nav1]-crs
  cdangle=(cdangle+360)%360
  if(cdangle>180) cdangle-=360
  if cdangle>90 then cdangle=180-cdangle --backcourse
  elseif cdangle<-90 then cdangle=-180-cdangle end
  cdi=18/10*cdangle --5 deg full deflection
  if(abs(cdi)>9) cdi=9*cdi/abs(cdi)
end

function checklanded()
  if alt==0 and (onground==false) then
   onground=true
   t=rec+60 --message displayed for 2s
			if vs>-300 and pitch>-0.5 then hardlanding=0
			elseif vs>-1000 and pitch>-0.5 then hardlanding=1
			else hardlanding=2 end
	 end
		if alt>0 and (onground==true) then
			onground=false
			--t=rec+60
		end
end

function dispmessage()
  local message=false
		if ias>180 then
    menu=2
    return "crash: exceeded maximum speed"
  end
  if onground then
    if hardlanding==0 then
        message="good landing!"
    elseif hardlanding==1 then
        message="oops... hard landing"
				else
					 menu=2
						return "crash: collision with ground"
    end
  end
		if rec<t and message then
				local c = frame%16<8 and 7 or 9
				rectfill(0,9,127,15,5)
				print(message,10,10,c)
		end
end

function flaps()
  if btnp(5,1) then --q
    flps=1-flps --toggle
    plag=flps==1 and 70 or -70
  end
end

function dispflaps()
	line(4,74,4,79,5)
 line(5,74,5,79,13)
 if flps==1 then
   rectfill(2,78,7,79,7)
 else
   rectfill(2,74,7,75,7)
 end
end

function calcwind()
  relwind=heading-wind[1]
  relwind=(relwind+180)%360-180
  relh=-wind[2]*cos(relwind/360)
  relc=wind[2]*sin(relwind/360)
  groundspeed=sqrt((tas/10+relh/10)^2+(relc/10)^2) --/10: avoid tas^2 overflow
  groundspeed=flr(10*groundspeed+0.5)
  wca=atan2(tas+relh,relc)*360
  wca=(wca+180)%360-180
		if(alt==0) wca=0
		-- actual 2d velocity direction
  track=heading+wca
end

function dispwind()
  if relwind>=0 and relwind<90 then
    spr(5,41,96)
  elseif relwind<=0 and relwind>-90 then
    spr(5,37,96,1,1,true,false)
  elseif relwind>=90 and relwind<180 then
    spr(5,41,92,1,1,false,true)
  elseif relwind<=-90 and relwind>-180 then
    spr(5,37,92,1,1,true,true)
  end
end

function blackbox()
  rec+=1
  if(rec%150==1) add(flight, {lat,lon,alt})
end

function drawmenu()
  local c = frame%16<8 and 7 or 9
  cls()
  spr(2,25,10)
  spr(3,92,10)
  print("tiny sim v0.60",35,10,7)
  print("the world's smallest flight sim",2,20,6)
  print("flight:",8,37,item==0 and c or 7)
  print(scenarios[scen][1],44,37,7)
 	print("weather:",8,47,item==1 and c or 7)
  print(wx[wnd][1],44,47,7)
  print("press ❎ for briefing",8,57,7)
  print("x/z: throttle",8,80,6)
  print("q: toggle flaps",8,87,6)
  print("tab: toggle map / pause",8,94,6)
  rect(5,77,101,101,6)
  rectfill(70,88,75,89,7) --flaps
  spr(4,62,80) --throttle
  print("@yellowbaron | 3d by @freds72",7,123,6)
end

function drawmap(message)
  local c = frame%16<8 and 7 or 9
  cls()
  for l in all(db) do
    local x,y=scalemap(l[2],l[1])
    x-=3 --correct for sprite size
    y-=3
    --navaids
    if l[4]=="vor" then
      spr(39,x,y)
      print(l[3],x+9,y+1,7)
    elseif l[4]=="ils" then
      local a=(l[5]-3)/360
      local b=(l[5]+3)/360
      local _x=sin(a)
      local _y=cos(a)
      line(x+3,y+3,50*_x+x+3,50*_y+y+3,3)
      local _x=sin(b)
      local _y=cos(b)
      line(x+3,y+3,50*_x+x+3,50*_y+y+3,11)
      print(l[3],62*_x+x+2,62*_y+y+3,7)
    --airports
    elseif l[4]=="apt" then
      if l[5]>=0 and l[5]<23 then spr(22,x,y)
      elseif l[5]>22 and l[5]<68 then spr(55,x,y)
      elseif l[5]>67 and l[5]<103 then spr(54,x,y)
      elseif l[5]>102 and l[5]<148 then spr(55,x-1,y,1,1,true,false)
      else spr(22,x,y) end
      print(l[3],x+9,y+1,7)
    end
  end
  for l in all(flight) do
    local x,y=scalemap(l[2],l[1])
    pset(x,y,10)
  end
  if message then
    rectfill(0,9,127,15,5)
    print(message,10,10,c)
  else
			 rectfill(0,9,127,15,5)
				print("pause",10,10,c)
		end
  print("1 nm",112,110,7)
  line(112,108,120,108,7)
  print("tab: cockpit, z: exit to menu",0,123,6)
end

function scalemap(_x,_y)
  --based on 16nm per 128px
  return (_x/600)*128,128+(_y/600)*128
end

function drawbriefing()
  cls()
  print("flight briefing:",8,10,6)
  print(name,8,17,7)
  if scen==1 then
    local msg=[[
remain on runway axis. extend the
flaps and keep speed at 65-70
knots by using pitch and
throttle. at 50 feet, smoothly
close throttle and raise the
nose to gently touch down
below 65 knots.
too easy? add some wind!]]
    print(msg,8,30,6)
  elseif scen==2 then
    local msg=[[
fly heading of approx. 085
keep localizer (  ) centered
(the wind might push you away)
maintain 1000 ft
intercept glide slope ( )
reduce power and extend flaps
start 500 ft/min descent
keep localizer centered
keep glideslope centered
at 200 ft reduce power & land]]
    print(msg,8,30,6)
    -- icons
			spr(20,71,36)
			spr(38,100,55)
  elseif scen==3 then
    local msg=[[      
cross pco (  ) on heading 313
intercept localizer (  )
turn left heading 265
descend to 2000 ft
turn right heading 310
fly 1 minute
turn left heading 130
intercept localizer
turn left heading 085
fly final approach and land]]
    print(msg,8,30,6)
    -- icons
    spr(35,51,36)
    spr(20,91,42)
  elseif scen==4 then
    local msg=[[
you are enroute to tinyville
when the engine suddenly quits
fly best glide speed 65 knots
turn towards wee vor (  )
leave wee vor on heading 220
head towards smallville
glide to airport and land
good luck!]]
    print(msg,8,30,6)
    -- icons
    spr(35,95,51)
    spr(55,104,64)
  else
    local msg=[[
while checking the map you did
not pay attention to your
attitude. when you look up,
the airplane is out of control
at low altitude. oops!
can you recover?
hint: bank first, then pull up]]
    print(msg,8,30,6)
  end
  print("press ❎ to   fly",8,112,7)
  spr(2,54,112)
  spr(3,77,112)
  print("z: back to menu",8,119,6)
end

function drawstatic()
  rectfill(10,36,127,42,0) --navbar
  print("nav1",11,37,7)
  line(43,36,43,42,7)
  spr(7,47,37) --dto arrow
  print("dis",75,37,7)
  print("gs",107,37)
  rectfill(0,115,8,127,0) --rpm
  line(4,90,4,110,5)
  line(5,90,5,110,13)
  line(5,90,5,110,13)
  rectfill(11,97,33,119,0) --map
  line(40,71,45,71,10) --level
  line(83,71,88,71)
  rectfill(57,88,71,94,0) --hdg
  pset(70,89,7)
  rectfill(107,121,127,127,0) --timer
  line(45,111,47,111,7)
  line(81,111,83,111,7)
  spr(18,71,120,1,1,true,false) --bearing 2
  spr(34,79,115,1,1,true,false)
  rectfill(87,115,100,127,0)
  rectfill(79,123,86,127)
  spr(35,79,122,1,1,true,false) --nav2 arrow
  rectfill(40,95,45,100,0) --wind
end

function _update()
  frame+=1
  if menu==1 then --menu
    if btnp(5) then --x
      menu=3
      scenario(scen)
    elseif btnp(3) then --down
      item+=1
      item%=2
    elseif btnp(2) then --up
      item-=1
      item%=2
    elseif btnp(1) then --right
      if item==0 then
        scen+=1
        if(scen==#scenarios+1) scen=1
      elseif item==1 then
        wnd+=1
        if(wnd==#wx+1) wnd=1
      end
    elseif btnp(0) then --left
      if item==0 then
        scen-=1
        if(scen==0) scen=#scenarios
      elseif item==1 then
        wnd-=1
        if(wnd==0) wnd=#wx
      end
    end
  elseif menu==2 then --pause/map screen
    if btnp(4) then --z
      _init()
    elseif btnp(4,1) then --tab
      menu=0
    end
  elseif menu==3 then --briefing
    if btnp(5) then --x
      menu=0
      _update()
    elseif btnp(4) then --z
      _init()
    end
  else
    setrpm()
    movepitch()
    movebank()
    calcalt()
    calcheading()
    calcspeed()
    calcaoa()
    calcwind()
    calcposition()
    calcdistbrg()
    stall()
    calcgs()
    calccdi()
    checklanded()
				flaps()
    blackbox()
    --3d
  	zbuf_clear()

   local q=make_q(v_right,-pitch/360)
	  q_x_q(q,make_q(v_fwd,-bank/360))
	  local q2=make_q(v_up,heading/360-0.25)
	  q_x_q(q2,q)
	  -- avoid matrix skew
	  q_normz(q2)
	  -- update cam
	  cam:track({lat,(alt+4.4)/120,lon},q2) --correction for height of pilot in airplane

	  zbuf_filter(actors)

	  -- must be done after update loop
	  cam:update()

   if btnp(4,1) then --tab
     menu=2
   end
  end
end

function _draw()
  if menu==1 then
    drawmenu()
	 elseif menu==2 then
    message=dispmessage()
				drawmap(message)
	 elseif menu==3 then
	   drawbriefing()
	 else
    dispai()
    drawstatic()
    disphsi()
    disprpm()
    dispspeed()
    dispalt()
    dispvs()
    dispheading()
    disptime()
    dispmap()
    dispnav()
    dispgs()
    dispflaps()
    dispwind()
    -- 3d
	  clip(0,0,128,31)
	  rectfill(0,0,128,31,0)
	  draw_ground()
	  zbuf_draw()
	  clip()
			-- glareshield
  	spr(49,4,27)
  	spr(50,-4,29)
		sspr(15,24,1,8,12,26,116,8)			
		dispmessage()

    -- perf monitor!
    local cpu=flr(100*stat(1)).."%"
    print(cpu,2,3,2)
    print(cpu,2,2,7)
  end
end

-->8
-- 3d engine @freds72

-- register json context here
function nop() return true end

-- ground constants
local ground_shift,ground_colors,ground_level=2,{1,13,6}

-- zbuffer (kind of)
local drawables={}
function zbuf_clear()
	drawables={}
end
function zbuf_draw()
	local objs={}
	for _,d in pairs(drawables) do
		local p=d.pos
		local x,y,z,w=cam:project(p[1],p[2],p[3])
		-- cull objects too far
 --	if z>-3 then
			add(objs,{obj=d,key=z,x=x,y=y,z=z,w=w})
	--	end
	end
	-- z-sorting
	-- sort(objs)
	-- actual draw
	for i=1,#objs do
		local d=objs[i]
		d.obj:draw(d.x,d.y,d.z,d.w)
	end
end

function zbuf_filter(array)
	for _,a in pairs(array) do
		if not a:update() then
			del(array,a)
		else
			add(drawables,a)
		end
	end
end

function clone(src,dst)
	dst=dst or {}
	for k,v in pairs(src) do
		if(not dst[k]) dst[k]=v
	end
	return dst
end

function lerp(a,b,t)
	return a*(1-t)+b*t
end

-- edge cases:
-- a: -23	-584	-21
-- b: 256	-595	256
function sqr_dist(a,b)
	local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
	if abs(dx)>128 or abs(dy)>128 or abs(dz)>128 then
		return 32000
	end
	local d=dx*dx+dy*dy+dz*dz
	-- overflow?
	return d<0 and 32000 or d
end

function make_v(a,b)
	return {
		b[1]-a[1],
		b[2]-a[2],
		b[3]-a[3]}
end
function v_clone(v)
	return {v[1],v[2],v[3]}
end
function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
end
function v_normz(v)
	local d=v_dot(v,v)
	if d>0.001 then
		d=sqrt(d)
		v[1]/=d
		v[2]/=d
		v[3]/=d
	end
	return d
end
function v_scale(v,scale)
	v[1]*=scale
	v[2]*=scale
	v[3]*=scale
end
function v_add(v,dv,scale)
	scale=scale or 1
	v[1]+=scale*dv[1]
	v[2]+=scale*dv[2]
	v[3]+=scale*dv[3]
end

-- matrix functions
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	v[1],v[2],v[3]=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]
end
function m_x_xyz(m,x,y,z)
	return
		m[1]*x+m[5]*y+m[9]*z+m[13],
		m[2]*x+m[6]*y+m[10]*z+m[14],
		m[3]*x+m[7]*y+m[11]*z+m[15]
end
-- inline matrix invert
-- inc. position
function m_inv_x_v(m,v)
	local x,y,z=v[1]-m[13],v[2]-m[14],v[3]-m[15]
	v[1],v[2],v[3]=m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z
end

-- quaternion
function make_q(v,angle)
	angle/=2
	-- fix pico sin
	local s=-sin(angle)
	return {v[1]*s,
	        v[2]*s,
	        v[3]*s,
	        cos(angle)}
end
function q_clone(q)
	return {q[1],q[2],q[3],q[4]}
end
function q_normz(q)
	local d=v_dot(q,q)+q[4]*q[4]
	if d>0 then
		d=sqrt(d)
		q[1]/=d
		q[2]/=d
		q[3]/=d
		q[4]/=d
	end
end

function q_x_q(a,b)
	local qax,qay,qaz,qaw=a[1],a[2],a[3],a[4]
	local qbx,qby,qbz,qbw=b[1],b[2],b[3],b[4]

	a[1]=qax*qbw+qaw*qbx+qay*qbz-qaz*qby
	a[2]=qay*qbw+qaw*qby+qaz*qbx-qax*qbz
	a[3]=qaz*qbw+qaw*qbz+qax*qby-qay*qbx
	a[4]=qaw*qbw-qax*qbx-qay*qby-qaz*qbz
end
function m_from_q(q)
	local x,y,z,w=q[1],q[2],q[3],q[4]
	local x2,y2,z2=x+x,y+y,z+z
	local xx,xy,xz=x*x2,x*y2,x*z2
	local yy,yz,zz=y*y2,y*z2,z*z2
	local wx,wy,wz=w*x2,w*y2,w*z2

	return {
		1-(yy+zz),xy+wz,xz-wy,0,
		xy-wz,1-(xx+zz),yz+wx,0,
		xz+wy,yz-wx,1-(xx+yy),0,
		0,0,0,1
	}
end

-- only invert 3x3 part
function m_inv(m)
	m[2],m[5]=m[5],m[2]
	m[3],m[9]=m[9],m[3]
	m[7],m[10]=m[10],m[7]
end
function m_set_pos(m,v)
	m[13],m[14],m[15]=v[1],v[2],v[3]
end
-- returns foward vector from matrix
function m_fwd(m)
	return {m[9],m[10],m[11]}
end
-- returns up vector from matrix
function m_up(m)
	return {m[5],m[6],m[7]}
end
-- right vector
function m_right(m)
	return {m[1],m[2],m[3]}
end

function draw_actor(self,x,y,z,w)
	-- distance culling
	draw_model(self.model,self.m,x,y,z,w)
end

local znear,zdir=0.25,-1
function draw_model(model,m,x,y,z,w)
  -- edges
	local p={}
	for i=1,#model.e do
		local e=model.e[i]
		-- edges indices
		local ak,bk,c=e[1],e[2],e[3] or model.c
		-- edge positions
		local a,b=p[ak],p[bk]
		-- not in cache?
		if not a then
			local v=v_clone(model.v[ak])
			v_scale(v,m_scale)
			-- relative to world
			m_x_v(m,v)
			-- world to cam
			v_add(v,cam.pos,-1)
			m_x_v(cam.m,v)
			a,p[ak]=v,v
		end
		if not b then
			local v=v_clone(model.v[bk])
			v_scale(v,m_scale)
			-- relative to world
			m_x_v(m,v)
			-- world to cam
			v_add(v,cam.pos,-1)
			m_x_v(cam.m,v)
			b,p[bk]=v,v
		end
		-- line clipping aginst near cam plane
		-- swap end points
		-- simplified sutherland-atherton
		local az,bz=a[3],b[3]
		if(az<bz) a,b,az,bz=b,a,bz,az
		local den=zdir*(bz-az)
		local t,viz=1,false
		if az>znear and bz<znear then
			t=zdir*(znear-az)/den
			if t>=0 and t<=1 then
				-- intersect pos
				local s=make_v(a,b)
				v_scale(s,t)
				v_add(s,a)
				-- in-place
				b=s
			end
			viz=true
		elseif bz>znear then
	 	viz=true
	 end
	 
		-- draw line
		if viz==true then
 		local x0,y0,z0,w0=cam:project2d(a)
 		local x1,y1,z1,w1=cam:project2d(b)
 		-- is it a light line?
 		if e[4] then
 			lightline(x0,y0,x1,y1,c,t,w0,w1,e[4])
 		else
 			line(x0,y0,x1,y1,c)
 		end
		end
	end
end

--[[
  -- lights
  for _,l in pairs(model.l) do
 		local x,y,z,w=l.pos[1],l.pos[2],l.pos[3]
		x,y,z,w=cam:project(m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15])
    -- directional light?
    local c=l.c
    if l.n then
      local fwd,ln=m_fwd(cam.mw),v_clone(l.n)
      -- light dir in world space
      m_x_v(m,ln)
      -- facing light?
      if v_dot(fwd,ln)<0 then
      	local lup=v_clone(l.up)
      	m_x_v(m,lup)
      	--
      	c=v_dot(fwd,lup)>0 and 11 or 8
      end
    end
    pset(x,y,c)
  end
end
]]

-- sutherland-hodgman clipping
function plane_poly_clip(n,p,v)
	local dist,allin={},true
	for i=1,#v do
		dist[i]=v_dot(make_v(v[i],p),n)
		allin=band(allin,dist[i]>0)
	end
	-- early exit
	if(allin==true) return v

	local res={}
	local v0,d0=v[#v],dist[#v]
	for i=1,#v do
		local v1,d1=v[i],dist[i]
		if d1>0 then
			if d0<=0 then
				local r=make_v(v0,v1)
				v_scale(r,d0/(d0-d1))
				v_add(r,v0)
				add(res,r)
			end
			add(res,v1)
		elseif d0>0 then
			local r=make_v(v0,v1)
			v_scale(r,d0/(d0-d1))
			v_add(r,v0)
			add(res,r)
		end
		v0,d0=v1,d1
	end
	return res
end

function make_actor(src,p,angle)
	-- instance
	local a=clone(src,{
		pos=v_clone(p),
		-- north is up
		q=make_q(v_up,angle-0.25)
	})
 a.model=all_models[a.model]
	a.draw=a.draw or draw_actor
	a.update=a.update or nop
	-- init orientation
	local m=m_from_q(a.q)
	m_set_pos(m,p)
	a.m=m
	return a
end

function make_cam(x0,y0,focal)
	local c={
		pos={0,0,3},
		q=make_q(v_up,0),
		update=function(self)
      -- keep world orientation in mw
			self.mw,self.m=m_from_q(self.q),m_from_q(self.q)
			m_inv(self.m)
		end,
		track=function(self,pos,q)
			self.pos,q=v_clone(pos),q_clone(q)
			self.q=q
		end,
		project=function(self,x,y,z)
			-- world to view
			x-=self.pos[1]
			y-=self.pos[2]
			z-=self.pos[3]
			x,y,z=m_x_xyz(self.m,x,y,z)

			-- view to screen
	 	  local w=focal/z
 		  return x0+x*w,y0-y*w,z,w
		end,
		-- project cam-space points into 2d
  project2d=function(self,v)
  	-- view to screen
  	local w=focal/v[3]
  	return x0+v[1]*w,y0-v[2]*w,v[3],w
		end
	}
	return c
end

local stars={}
for i=1,48 do
	local v={rnd()-0.5,rnd(0.5),rnd()-0.5}
	v_normz(v)
	v_scale(v,32)
	add(stars,v)
end

local sky_gradient={0xee,0x2e,0x11}
local sky_fillp={0xffff,0xffff,0xffff}
function draw_ground(self)

	-- draw horizon
	local zfar=-256
	local x,y=-64*zfar/64,64*zfar/64
	local farplane={
			{x,y,zfar},
			{x,-y,zfar},
			{-x,-y,zfar},
			{-x,y,zfar}}
	-- ground normal in cam space
	local n={0,1,0}
	m_x_v(cam.m,n)

	for k=0,#sky_gradient-1 do
		-- ground location in cam space
		local p={0,cam.pos[2]-8*k*k,0}
		m_x_v(cam.m,p)

		local v0=farplane[#farplane]
		local sky=plane_poly_clip(n,p,farplane)
		-- complete line?
		fillp(sky_fillp[k+1])
		polyfill(sky,sky_gradient[k+1])
	end
 fillp()

 -- stars
	for _,v in pairs(stars) do
		local x,y,z,w=cam:project(cam.pos[1]+v[1],cam.pos[2]+v[2],cam.pos[3]+v[3])
		if(z>0) pset(x,y,7)
	end

	local cy=cam.pos[2]

	local scale=4*max(flr(cy/32+0.5),1)
	scale*=scale
	local x0,z0=cam.pos[1],cam.pos[3]
	local dx,dy=x0%scale,z0%scale

	for i=-4,4 do
		local ii=scale*i-dx+x0
		for j=-4,4 do
			local jj=scale*j-dy+z0
			local x,y,z,w=cam:project(ii,0,jj)
			if z>0 then
				pset(x,y,3)
			end
 		end
	end
end

-- draw a light line
-- note: u0 is assumed to be zero
function lightline(x0,y0,x1,y1,c,u1,w0,w1,n)
 local w,h=abs(x1-x0),abs(y1-y0)
 
 -- adjust remaining number of points
 n=flr(n*u1)
 if(n<1) return
 
 local u0,t,prevu=0,0,-1
   
 color(c)
 if h>w then
  -- too small?
  if 1.8*h<n then
   line(x0,y0,x1,y1)
   return
  end

  -- order points on y
  if(y0>y1) x0,y0,x1,y1,u0,u1,w0,w1=x1,y1,x0,y0,u1,u0,w1,w0
  w=x1-x0

  -- y-major
  if(y0<0) x0,y0,t=x0-y0*w/h,0,-y0/h
  
  u0*=n*w0
  u1*=n*w1
  for y=y0,min(y1,127) do	
   -- perspective correction
   local u=flr(lerp(u0,u1,t)/lerp(w0,w1,t))
   if(prevu!=u) pset(x0,y)
   x0+=w/h
   t+=1/h
   prevu=u
  end

  else
   if 1.8*w<n then
    line(x0,y0,x1,y1)
    return
   end

   -- x-major
   if(x0>x1) x0,y0,x1,y1,u0,u1,w0,w1=x1,y1,x0,y0,u1,u0,w1,w0
   h=y1-y0

   if(x0<0) x0,y0,t=0,y0-x0*h/w,-x0/w
   
	  u0*=n*w0
	  u1*=n*w1
   for x=x0,min(x1,127) do
    local u=flr(lerp(u0,u1,t)/lerp(w0,w1,t))
    if(prevu!=u) pset(x,y0)
    y0+=h/w
    t+=1/w
    prevu=u
   end
  end
end
-->8
-- trifill
-- by @p01
function p01_trapeze_h(l,r,lt,rt,y0,y1)
  lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
  if(y0<0)l,r,y0=l-y0*lt,r-y0*rt,0
   for y0=y0,min(y1,128) do
   rectfill(l,y0,r,y0)
   l+=lt
   r+=rt
  end
end
function p01_trapeze_w(t,b,tt,bt,x0,x1)
 tt,bt=(tt-t)/(x1-x0),(bt-b)/(x1-x0)
 if(x0<0)t,b,x0=t-x0*tt,b-x0*bt,0
 for x0=x0,min(x1,128) do
  rectfill(x0,t,x0,b)
  t+=tt
  b+=bt
 end
end

function trifill(x0,y0,x1,y1,x2,y2,col)
 color(col)
 if(y1<y0)x0,x1,y0,y1=x1,x0,y1,y0
 if(y2<y0)x0,x2,y0,y2=x2,x0,y2,y0
 if(y2<y1)x1,x2,y1,y2=x2,x1,y2,y1
 if max(x2,max(x1,x0))-min(x2,min(x1,x0)) > y2-y0 then
  col=x0+(x2-x0)/(y2-y0)*(y1-y0)
  p01_trapeze_h(x0,x0,x1,col,y0,y1)
  p01_trapeze_h(x1,col,x2,x2,y1,y2)
 else
  if(x1<x0)x0,x1,y0,y1=x1,x0,y1,y0
  if(x2<x0)x0,x2,y0,y2=x2,x0,y2,y0
  if(x2<x1)x1,x2,y1,y2=x2,x1,y2,y1
  col=y0+(y2-y0)/(x2-x0)*(x1-x0)
  p01_trapeze_w(y0,y0,y1,col,x0,x1)
  p01_trapeze_w(y1,col,y2,y2,x1,x2)
 end
end

function polyfill(p,c)
	if #p>2 then
		local x0,y0=cam:project2d(p[1])
		local x1,y1=cam:project2d(p[2])
		for i=3,#p do
			local x2,y2=cam:project2d(p[i])
			trifill(x0,y0,x1,y1,x2,y2,c)
			x1,y1=x2,y2
		end
	end
end

__gfx__
00000000fff7777f49777777777777e25fffffff7fffffff77ff777fffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ff7fffffffffffffffffffff55fffffff7f7ffff7f7f777ffffffeff0000000000000000000000000000000000000000000000000000000000000000
00000000f7ffffffff3b77777777d5ff555fffffff77ffff7f7f7f7feeeeeeef0000000000000000000000000000000000000000000000000000000000000000
000000007fffffffffffffffffffffff55fffffff777fffffffffffffffffeff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffff1c7777c1ffff5fffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
0000000070707070ffffffff77777fffffbfffff00000000ff222fffffffffff0000000000000000000000000000000000000000000000000000000000000000
0000000007000700fffffffff777fffffbffffff00000000f2e7e2ffff0fffff0000000000000000000000000000000000000000000000000000000000000000
0000000070700700ffffffffff7fffffbbbbbbbb000000002ee7ee2ff00fffff0000000000000000000000000000000000000000000000000000000000000000
00000000000000000ffffffffffffffffbffffff000000002ee7ee2f000fffff0000000000000000000000000000000000000000000000000000000000000000
000000000000777000ffffffffffffffffbfffff000000002ee7ee2ff00fffff0000000000000000000000000000000000000000000000000000000000000000
0000000000007700000fffffffffffffffffffff00000000f2e7e2ffff0fffff0000000000000000000000000000000000000000000000000000000000000000
000000000000707000000fffffffffffffffffff00000000ff222fffffffffff0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000ffffffffffffffff00000000ffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ff7fffff00000fffffcfffff777fffff777ffffffbffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
0000000077777fff00000ffffcffffff7fffffff77ffffffbbbfffffffcccfff0000000000000000000000000000000000000000000000000000000000000000
00000000ff7fffff000000ffccccccccff7fffff7ffffffffbfffffffcfffcff0000000000000000000000000000000000000000000000000000000000000000
00000000ff7fffff000000fffcffffff777fffff777ffffffffffffffcfcfcff0000000000000000000000000000000000000000000000000000000000000000
00000000f777ffff000000ffffcffffffffffffffffffffffffffffffcfffcff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff0000000fffffffffffffffffffffffffffffffffffcccfff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff0000000fffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffff00000000ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000fff66666ffffff66000fffff77ffffff7f7fffffff222fffff222fff0000000000000000000000000000000000000000000000000000000000000000
0000000066677777ffff6677070fffff7f7fffff7f7ffffff2eee2fff2eee2ff0000000000000000000000000000000000000000000000000000000000000000
0000000077755555ffff7755070fffff7f7fffff777fffff2eeeee2f2eee7e2f0000000000000000000000000000000000000000000000000000000000000000
0000000055511111ffff5511070fffff7f7fffff777fffff2777772f2ee7ee2f0000000000000000000000000000000000000000000000000000000000000000
0000000011100000ffff1100070fffffffffffffffffffff2eeeee2f2e7eee2f0000000000000000000000000000000000000000000000000000000000000000
0000000000000000ffff0000070ffffffffffffffffffffff2eee2fff2eee2ff0000000000000000000000000000000000000000000000000000000000000000
0000000000000000ffff0000000fffffffffffffffffffffff222fffff222fff0000000000000000000000000000000000000000000000000000000000000000
00000000000fffffffff00ffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000888880000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000006607060000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000066007006000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000060007006600000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000600007000600000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000006600007000060000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000006000000000006000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000060000007000006000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000600000007000000600000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000006000000007000000060000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000060000000000000000006000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000b000b000b0000b000b0000b0000000000000000000000000000000000000000000000000000
00000000000055555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
00000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
00005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
00555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55000000000066666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00000006666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00006666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00666666660000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666666077007770707077000bbb0bbb0bb0000070000ee000000eee0ee00e0e000000007700777007700eee00000ee000000000077007700eee0eee00000
66666666660707070707070070000b000b00b0b000070000e0e0e0000e00e0e0e0e000000007070070070000e0e000000e00000000070007000000e000e00000
66666666660707077707070070000b000b00b0b00007000eeeeeee000e00e0e0eee000000007070070077700e0e000000e00000000070007770000e00ee00000
66666666660707070707770070000b000b00b0b000070000e0e0e0000e00e0e000e000000007070070000700e0e000000e00000000070700070000e000e00000
6666666666070707070070077700bbb00b00b0b000070000eee000000e00e0e0eee000000007770777077000eee00e00eee0000000077707700000e0eee00000
66666666660000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccc777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccc777777777ccccccccccccccccccccccdddcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccd7dcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddddddddddddcccccccccccccccc
6666666666cccccccccccdddddddd00000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddd070707070cccccccccccccccc
6666666666cccccccccccdddddddd07770cccccccccccccccccccccccccccccccccccccccccccccccccccccccccd7dcdddddddd077707770cccccccccccccccc
6666666666cccccccccccdddddddd00070cccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddcdddddddd000000000cccccccccccccccc
6666666666ccccccccccc0000000000770cccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddc00000000077707770cccccccccccccccc
66666666664444444444400000777000704444444444444444444444444444444444444444444444444444444445554000007770707070704444444444444444
66666666664444444444400000007077704444444444444444444444444444444444444444444444444444444445554000007070777070704444444444444444
6666666666444444444440000000700000444444aaaaaa44444444444444444aaa44444444444444444aaaaaa447774000007070007070704444444444444444
66666666664444444444400000007077704444444444444444444444444aaaa444aaaa4444444444444444444445554000007070007077704444444444444444
6666666666444444444440000000700070444444444444444444444aaaa44444444444aaaa444444444444444445554000007770000000004444444444444444
66665d666644444444444000000000777044444444444444444aaaa4444444444444444444aaaa44444444444445554000000000777077704440000000000004
66665d666644444444444555555550700044444444444444aaa444444444444444444444444444aaa44444444445554555555550707070704400000700000004
66665d66664444444444455555555077704444444444444444444444444444444444444444444444444444444445754555555550777070704000000700000004
66665d66664444444444455555555000004444444444444444444444444444444444444444444444444444444445554555555550707070700007770777000004
66777777664444444444455555555555554444444444444444444444444477777777744444444444444444444445554555555555555555554000000707000004
66777777664444444444455555555555554444444444444444444444444444444444444444444444444444444445554555555555555555554400000777000004
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444445554555555555555555554440000000000004
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444445754555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444445b54555555555555555554444444444444444
6666666666444444444445555555555555444444444444444444444444444444444444444444444444444444444bbb4555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444445b54555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444444444555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444444444555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444444444444444444444444444444444444444444555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444400000000000000044444444444444444444444555555555555555554444444444444444
66666666664444444444455555555555554444444444444444444444407770777070707044444444444444444444444555555555555555554444444444444444
66665d66664444444444455555555555554444444444444444444444407070707070700044444444444444444444444555555555555555554444444444444444
66665d66664444444444444444444444444444444444444444444444407070777077700044444444444444444444444444444444444444444444444444444444
66665d66664444444444444444444444444444444444444444444444407070707000700044444444444444444444444444444444444444444444444444444444
66665d66664444444444444444444444444444444444444444444444407770777000700044444444444444444444444444444444444444444444444444444444
66665d66664444444444444444444444444444444444444444444444400000000000000044444444444444444444444444444444444444444444444444444444
66665d66664444444444444444444444444444440000004444444444444444777774444444444444444444444444444444444444444444444444444444444444
66665d66664444444444444444444444444444440700004444444444444445577755444444444444444444444444444444444444444444444444444444444444
66665d66664000000000000000000000004444440070704444444444445555557555555444444444444444444444444444444444444444444444444444444444
66665d6666400000000000000000000000444444000770444444444455555555b775555554444444444444444444444444444444444444444444444444444444
66665d66664000000000000000000000004444440077704444444445555555bbbb55555555444444444444444444444444444444444444444444444444444444
66665d6666400000000000000000000000444444000000444444445555555555b5b5555555544444444444444444444444444444444444444444444444444444
66665d6666400000000000000000000000444444444444444444455555555555b775555555554444444444444444444444444444444444444444444444444444
65665d6666400000000000000000000000444444444444444444555555555555b555555555555444444444444444444444444444444444444444444444444444
65565d666640000000000000000000000044444444444444444555555555557b7775555555555544444444444444444444444444444444444444444444444444
65555d666640000000000000000000000044444444444444444555555555775b5557755555555544444444444444444444444444444444444444444444444444
65565d666640000000000000000000000044444444444444445555555557555b5555575555555554444444444444444444444444444444444444444444444444
65665d666640000000000000000000000044444444444444445555555575555b5555557555c55554444444444444444444444444444444444444444444444444
66665d666640000000000000000000000044444444444444445555555755555b55555557555c5554444444444444444444444444444444444444444444444444
66665d666640000000000000000000000044444444444444455775555755555b55555557555cc555444444444444444444444444444444444444444444444444
66665d666640000000000000000000000044444444444444455757557555555b55555555ccc5c555444444444444444444444444444444444444444444444444
66665d666640000000000070000000000044444444444444455757557555555b75555555755c5555444444444444444444444444444444444444444444444444
66666666664000000000777770000000004444444444477745575755755555777775555575777555477744444444444444444444444444444444444444444444
666666666640000000000070000000000044444444444444455555cc7555555b7555555575755555444444444444444444444444444444444444444444444444
666666666640000000000070000000000044444444444444455ccc557555555b7555555575557555444444444444444444444444444444444444444444444444
66666666664000000000077700000000004444444444444445555555575555577755555755777555444444444444444444444444444444444444444444444444
000000000640000000000000000000000044444444444444445555555755555b5555555755555554440000000000000000000444444444444444444444444444
077007700640000000000000000000000044444444444444445555555575555b5555557555555554440000000707000007770444444444444444444444444444
007000700640000000000000000000000044444444444444445555555557555b5555575555555554400000000707000000070444444444444444444444444444
00700070064000000000000000000000004444444444444444455555555577555557755555555544400000000777000000070444444444444444444444444444
007000700640000000000000000000000044444444444444444555555555557b7775555555555544400000000007000000070444444444444444444444444444
077707770644444444444444444444444444444444444444444455555555555b5555555555555444000000000007007000070444444444444444444444444444
000000000644444444444444444444444444444444444444444445555555575b5555555555554444000000000000000000000444444000000000000000000000
077707770644444444444444444444444444444444444444444444555555575b55555555555444400000c0000ccc00cc00cc0444444077707700000077707000
070007070644444444444444444444444444444444444444444444455555577b555555555544440000000c000c0c0c000c0c0444444070700700070070707000
0777070706444444444444444444444444444444444444444444444455555777555555555444400cccccccc00ccc0c000c0c0444444070700700000070707770
0007070706444444444444444444444444444444444444444444444444555555555555544444000000000c000c000c000c0c0444444070700700070070707070
077707770644444444444444444444444444444444444444444444444444455555554444440000000000c0000c0000cc0cc00444444077707770000077707770
00000000064444444444444444444444444444444444444444444444444444444444444000000000000000000000000000000444444000000000000000000000

__map__
0808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000600022223022230232002320024200242002320022200212002120021200212002120003700037000470004700057000570005700057000570005700057000470004700037000270002700027000170001700
