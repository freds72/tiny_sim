pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--tiny sim 0.50
--t cueni

--scenarios (name,lat,lon,hdg,alt,pitch,bank,throttle,gps dto,nav1,nav2)
scenarios={{"visual approach",-417,326.3,85,600,-1,0,25,3,2,1},
           {"final approach",-408.89,230.77,85,1000,1,0,75,3,2,1},
           {"full approach",-222.22,461.54,313,3000,0,0,91,3,2,1},
           {"engine failure!",-244.44,261.54,50,3500,0,0,0,4,2,5},
           {"unusual attitude",-222.22,461.54,330,450,99,99,100,3,2,1}}
--weather (name,wind,ceiling)
wx={{"clear, calm",{0,0},20000},
    {"clouds, breezy",{60,10},500},
    {"low clouds, stormy",{10,45},200}}

--airport and navaid database (rwy hdg < 180)
db={{-251.11,430.77,"pco","vor"},
    {-422.22,384.62,"itn","ils",85},
    {-422.22,384.62,"tny","apt",85},
    {-66.67,153.85,"smv","apt",40},
    {-177.78,246.15,"wee","vor"}}

--general settings and vars
palt(15,true)
palt(0,false)
frame=0

--instruments
--ai
aic={64,71} --center
ai={{-87,72},{215,72},{64,-79},{64,223}}
aipitch = {60,141}
aistep=10
aiwidth=8

--hsi
hsic={64,111} --center
bp={{{64,98},{64,102},{62,100},{66,100},{64,120},{64,124}},
    {{1,2},{1,3},{1,4},{5,6}}} --bearing pointer
nesw={{64,99,52},{52,111,53},{64,123,36},{76,111,37}} --cardinal directions
cdii={{{64,98},{64,102},{62,100},{66,100},{64,120},{64,124},{64,104},{64,118}},
    {{1,2},{1,3},{1,4},{5,6},{7,8}}} --cdi

--inset map
mapc={22,111} --center
mapclr={apt=14,vor=12,ils=15}

--3d
rwy = {} 
for i = 1,31 do -- rwy sides and center
 add(rwy, {-1,0,-i,6})
 add(rwy, {1,0,-i,6})
 if(i < 21) add(rwy, {0,0,-i*1.5,7})
end
for i = 0,5 do -- rwy ends
 add(rwy, {-1+i*0.4,0,0,11})
 add(rwy, {-1+i*0.4,0,-31,8})
end

function _init()
  cls()
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
  rec=0
  flight={}
  --3d
  objects 	= {}
  create_object(rwy,{384.6,0,-422.2},85) --tny 
	 create_object(rwy,{153.8,0,-66.7},40) --smv
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
  --3d
  update_engine()
end

function unusual()
  local sign=1
  if(rnd(2)<1) sign=-1
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
  if(throttle<=0) throttle=0
  if(throttle>=100) throttle=100
  --calculate rpm  
  maxrpm=2400
  if(alt>=2000) maxrpm=2456-0.028*alt
  targetrpm=throttle/100*(maxrpm-700)+700
  rpm+=(targetrpm-rpm)/20
  if(abs(targetrpm-rpm)>=30) plag=(targetrpm-rpm)/20 
  if(rpm<=700) rpm=700
end

function disprpm()
  drpm=flr(rpm/10+0.5)*10
  if(drpm<=2000) then c=7 --white
  elseif(drpm<=2400) then c=11 --green
  end
  if(drpm>=1000) then
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
    plag-=2
    if(plag<=-60) plag=-60
    pitch-=0.25*cos(bank/360)
  elseif (btn(3) and aoa<18) then --pitch up
    plag+=2
    if(plag>=60) plag=60
    pitch+=0.35*cos(bank/360)
  elseif(plag!=0) then
    pitch+=0.004*plag*cos(bank/360)
    plag-=plag/abs(plag) 
  end
  if(abs(pitch)>=45) pitch=45*pitch/abs(pitch)
end

function movebank()
  if btn(0) then
    blag-=1
    if(blag<=-50) blag=-50
    bank-=1.8-tas/250
  elseif btn(1) then
    blag+=1
    if(blag>=50) blag=50
    bank+=1.8-tas/250
  elseif(blag!=0) then
    bank+=0.03*blag
    blag-=blag/abs(blag) 
  end
  if (abs(bank)<4 and blag==0) bank=bank/1.1 --bank stability
  if(abs(bank)>20) pitch-=0.3*abs(sin(bank/360))
  if(abs(bank)>160) pitch-=0.15
  if(bank>180) bank=bank-360
  if(bank<-180) bank=360+bank
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
  trifill(ax,ay,bx,by,cx,cy,12)
  trifill(ax,ay,bx,by,dx,dy,4)
  clip(35,44,55,43)
  for j=0,15 do
    local tmp=aipitch[2]-j*aistep+pitch
    x1,y1=rotatepoint({aipitch[1],tmp},aic,-bank)
    x2,y2=rotatepoint({aipitch[1]+aiwidth,tmp},aic,-bank)
    if(j!=7) line(x1,y1,x2,y2,7)  
  end
  warn(-8,3)
  warn(110,3)
  clip()
  --transparency
  transrect(21,50,33,90)
  transrect(95,50,111,90)
  rectfill(0,26,127,42,6)
  rectfill(0,26,9,127)
  rectfill(0,0,127,25,0) 
  line(48,75,aic[1],aic[2],10) --aircraft symbol
  line(80,75,aic[1],aic[2])
end

-- TODO: optimize
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
    x1,y1=rotatepoint({aipitch[1],_y},aic,-bank)
    x2,y2=rotatepoint({aipitch[1]+aiwidth/2,_y+(aistep-2)*j},aic,-bank)
    x3,y3=rotatepoint({aipitch[1]+aiwidth,_y},aic,-bank)
    line(x1,y1,x2,y2,8)
    line(x3,y3,x2,y2)
  end
end

function calcalt()
  local coeff=88
  if(vs<0) coeff=74
  vs=tas*-(sin((pitch-aoa)/360))*coeff
  alt+=vs/1800
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
  if(alt>=9995) then
    rectfill(91,68,94,74,0)
    z=92
  elseif(alt<995) then
    z=100  
  else
    z=96  
  end
  print(flr((_y+0.5)/10),z,69,7)
end

function dispvs()
  vsoffset=flr(vs/100+0.5)
  if(vsoffset>=21) then
    vsoffset=21
  elseif(vsoffset<=-19) then
    vsoffset=-19
  end
  rectfill(115,68-vsoffset,126,74-vsoffset,0)
  spr(23,112,68-vsoffset)
  if(vsoffset!=0) print(flr(vs/100+0.5),115,69-vsoffset,7)
end

function calcheading()
  if(abs(bank)<=90) then heading+=bank*0.007
    else heading+=(180-abs(bank))*bank/abs(bank)*0.007 end
  if(heading>=360) then
    heading-=360
  elseif(heading<=0) then
    heading+=360
  end
end

function dispheading()
 local hdg=flr(heading+0.5)%360
 if(hdg<10) then print("00"..hdg,58,89,7)
 elseif(hdg<100) then print("0"..hdg,58,89,7)
 else print(hdg,58,89,7) end
end

function calcspeed()
  targetspeed=38.67+rpm/30-3.8*pitch --3.6
  if(targetspeed>200) targetspeed=200
  if(targetspeed<-30) targetspeed=-30
  if(flps==1) targetspeed-=10
  tas+=(targetspeed-tas)/250
  ias=tas/(1+alt/1000*0.02) --2% per 1000 ft
end

function dispspeed()
  if(ias>=163) then c=8 --red
    else c=0
  end  
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
  local z
  if(ias>=99.5) then z=22
    else z=26
  end
  print(flr((ias+0.5)/10),z,69)
  print(groundspeed,116,37,14)
end

function calcaoa()
  if(ias>=71.1) then
    aoa=13.2-0.12*ias
  elseif(ias>=46.7) then
    aoa=26-0.3*ias
  else
    aoa=54-0.9*ias
  end
  if(aoa<=0) aoa=0
end

function calcposition()
   local dx=-groundspeed*sin(track/360)/2880
   local dy=groundspeed*cos(track/360)/2880
   lon+=dx
   lat-=dy
end

function disptime()
  timer+=1/30
  minutes=flr(timer/60)
  seconds=flr(timer-minutes*60)
  if(minutes<10) minutes="0"..minutes
  if(seconds<10) seconds="0"..seconds
  disptimer=minutes..":"..seconds
  print(disptimer,108,122)
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
  if((p[1]>11 and p[1]<33) and (p[2]>97 and p[2]<120)) return true
  return false
end

function calcdistbrg()
  j=1
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
  --todo: eats 20% cpu
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
    x,y=rotatepoint(l,hsic,-heading)
    spr(l[3],x-1,y-1)
  end
  --bearing pointer
  for l in all(bp[2]) do
    x1,y1=rotatepoint(bp[1][l[1]],hsic,brg[nav2])
    x2,y2=rotatepoint(bp[1][l[2]],hsic,brg[nav2])
    line(x1,y1,x2,y2,12)
  end
  --cdi
  crs=db[nav1][5]-heading
  cdii[1][7][1]=cdi+64
  cdii[1][8][1]=cdi+64
  for l in all(cdii[2]) do
    x1,y1=rotatepoint(cdii[1][l[1]],hsic,crs)
    x2,y2=rotatepoint(cdii[1][l[2]],hsic,crs)
    line(x1,y1,x2,y2,11)
  end
  spr(33,62,110) --heading plane symbol
end

function rotatepoint(p,c,angle)
  local x=((p[1]-c[1])*cos(angle/360)+(p[2]-c[2])*sin(angle/360))+c[1]
  local y=(-(p[1]-c[1])*sin(angle/360)+(p[2]-c[2])*cos(angle/360))+c[2]
  return x,y
end

function dispdist(j,x,y,c)
  if(dist[j]<10) then
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
  if(aoa>=critical) then
    slag=45
    plag=0
    blag=-10
  end
  pitch-=slag*0.008
  if (slag>=1) slag-=1
end

function calcgs() --glideslope
    local alpha=atan2(alt/6072,dist[nav1])*360-270
    gsy=63+10/0.7*(alpha-3)
    if(gsy<=50) then gsy=50
    elseif(gsy>=74) then gsy=74 end
end

function dispgs() --glideslope
  if((dist[nav1]<15) and (alt< 9995)) then
    transrect(91,58,93,84)
    for j=0,4 do pset(92,61+j*5,7) end
    line(91,71,93,71,7)
    spr(38,91,gsy+8)
  end
end

function calccdi()
  cdangle=brg[nav1]-crs
  cdangle=(cdangle+360)%360
  if(cdangle>180) cdangle-=360
  if(cdangle>90) then cdangle=180-cdangle --backcourse
  elseif(cdangle<-90) then cdangle=-180-cdangle end
  cdi=18/10*cdangle --5 deg full deflection
  if(abs(cdi)>9) cdi=9*cdi/abs(cdi)
end  

function crash()
  if(ias>180) then
    menu=2
    return "crash: exceeded vmax"
  end
  if(alt<=9) then
    menu=2
    local h=abs(heading-db[dto][5])
    if (vs>-300) and (tas<65) and (pitch>=0) then 
      if (h<5 or abs(h-180)<5) and (dist[dto]<0.3) then
        return "good landing!"
      else
        return "off-airport landing..."
      end
    else
      return "crash: collision with terrain"  
    end
  end
  return false
end

function flaps()
  if btnp(5,1) then --q
    flps=1-flps --toggle
    if(flps==1) then plag=70
    elseif(flps==0) then plag=-70 end
  end   
end

function dispflaps()
 line(4,74,4,79,5)
 line(5,74,5,79,13)
 if(flps==1) then
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
  track=heading+wca
end

function dispwind()
  if(relwind>=0) and (relwind<90) then
    spr(5,41,96)
  elseif(relwind<=0) and (relwind>-90) then
    spr(5,37,96,1,1,true,false)
  elseif(relwind>=90) and (relwind<180) then
    spr(5,41,92,1,1,false,true)
  elseif(relwind<=-90) and (relwind>-180) then
    spr(5,37,92,1,1,true,true)
  end
end

function blackbox()
  rec+=1
  if(rec%150==1) add(flight, {lat,lon,alt})
end

--triangle fill functions written by nusan
function clip2(v)
	return max(-1,min(128,v))
end

function lerp(a,b,alpha)
	return a*(1.0-alpha)+b*alpha
end

function drawmenu()
  local c = frame%16<8 and 7 or 9
  cls()
  spr(2,25,10)
  spr(3,92,10)	
		print("tiny sim v0.50",35,10,7)
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
		print("tc 2018",49,123,6)
end

function drawmap(message)
  local c = frame%16<8 and 7 or 9
  cls() 
  for l in all(db) do
    local x,y=scalemap(l[2],l[1])
    x-=3 --correct for sprite size
    y-=3
    --navaids
    if(l[4]=="vor") then
      spr(39,x,y)
      print(l[3],x+9,y+1,7)
    elseif(l[4]=="ils") then
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
    elseif(l[4]=="apt") then  
      if(l[5]>=0 and l[5]<23) then spr(22,x,y)
      elseif(l[5]>22 and l[5]<68) then spr(55,x,y)
      elseif(l[5]>67 and l[5]<103) then spr(54,x,y)
      elseif(l[5]>102 and l[5]<148) then spr(55,x-1,y,1,1,true,false)
      else spr(22,x,y) end
      print(l[3],x+9,y+1,7)
    end  
  end
  for l in all(flight) do
    local x,y=scalemap(l[2],l[1])
    pset(x,y,10)
  end
  if(message) then
    rectfill(1,9,128,15,5)
    print(message,10,10,c)
  end
  print("1 nm",112,110,7)
  line(112,108,120,108,7)
  print("tab: cockpit, z: exit to menu",0,123,6)
end

function scalemap(_x,_y)
  --based on 16nm per 128px
  local y=128+_y/600*128
  local x=_x/600*128
  return x,y
end

function drawbriefing()
  cls()
  print("flight briefing:",8,10,6)
  print(name,8,17,7)
  if(scen==1) then
    print("remain on runway axis. extend the",8,30,6)
    print("flaps and keep speed at 65-70",8,37)
    print("knots by using pitch and",8,44)
    print("throttle. at 50 feet, smoothly",8,51)
    print("close throttle and raise the",8,58)
    print("nose to gently touch down",8,65)
    print("below 65 knots.",8,72)
    print("too easy? add some wind!",8,79)
  elseif(scen==2) then
    print("fly heading of approx. 085",8,30,6)
		  print("keep localizer (  ) centered",8,37)
		  spr(20,71,37)
		  print("(the wind might push you away)",8,44)
		  print("maintain 1000 ft",8,51)
		  print("intercept glide slope ( )",8,58)
		  spr(38,100,59)
    print("reduce power and extend flaps",8,65)
    print("start 500 ft/min descent",8,72)
    print("keep localizer centered",8,79)
    print("keep glideslope centered",8,86)
    print("at 200 ft reduce power & land",8,93)
  elseif(scen==3) then
    print("cross pco (  ) on heading 313",8,30,6)
		  spr(35,51,30)
		  print("intercept localizer (  )",8,37)
		  spr(20,91,37)
		  print("turn left heading 265",8,44)
		  print("descend to 2000 ft",8,51)
		  print("turn right heading 310",8,58)
    print("fly 1 minute",8,65)
    print("turn left heading 130",8,72)
    print("intercept localizer",8,79)
    print("turn left heading 085",8,86)
    print("fly final approach and land",8,93)
  elseif(scen==4) then 
    print("you are enroute to tinyville",8,30,6)
		  print("when the engine suddenly quits",8,37)
		  print("fly best glide speed 65 knots",8,44)
		  print("turn towards wee vor (  )",8,51)
		  spr(35,95,51)
		  print("leave wee vor on heading 220",8,58)
		  print("head towards smallville",8,65)
		  spr(55,104,64) 
		  print("glide to airport and land",8,72)
    print("good luck!",8,79)
  else
    print("while checking the map you did",8,30,6)
		  print("not pay attention to your",8,37)
		  print("attitude. when you look up,",8,44)
		  print("the airplane is out of control",8,51) 
		  print("at low altitude. oops!",8,58)
		  print("can you recover?",8,65)
    print("hint: bank first, then pull up",8,72)
  end
  print("press ❎ to   fly",8,112,7)
  spr(2,54,112)
  spr(3,77,112)
  print("z: back to menu",8,119,6)
end

function drawstatic()
  rectfill(12,26,128,29,5) --glareshield
  rectfill(12,30,128,32,0)
  spr(49,4,27)
  spr(50,-4,29)
  line(0,26,11,26,0)
  line(0,27,6,27)
  line(0,28,3,28)
  line(0,29,1,29)
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
  if(menu==1) then --menu
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
      if(item==0) then 
        scen+=1
        if(scen==#scenarios+1) scen=1
      elseif(item==1) then
        wnd+=1
        if(wnd==#wx+1) wnd=1
      end
    elseif btnp(0) then --left
      if(item==0) then
        scen-=1
        if(scen==0) scen=#scenarios
      elseif(item==1) then
        wnd-=1
        if(wnd==0) wnd=#wx
      end
    end
  elseif(menu==2) then --pause/map screen
    if btnp(4) then --z
      _init()
    elseif btnp(4,1) then --tab
      menu=0
    end
  elseif(menu==3) then --briefing
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
    message=crash()
    flaps()
    blackbox()
    --3d
	   update_engine()
    if btnp(4,1) then --tab
      message="pause"
      menu=2
    end 
  end
end

function _draw()
  if(menu==1) then
    drawmenu() 
	 elseif(menu==2) then
    drawmap(message)
	 elseif(menu==3) then
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
    --3d
	   -- draw all the objects
	   --[[
	   if(alt<ceiling) then
	     for shape in all(objects) do
		      local np={}
		      for p in all(shape.points) do
          local nt = {}
          nt[1] = p[1] + shape.pos[1]
          nt[2] = p[2] + shape.pos[2]
          nt[3] = p[3] + shape.pos[3]
          nt[4] = p[4]
          add(np, nt)
        end
        draw_points(np)
      end
    end
    ]]
  end
  print(stat(1),2,2,7)
end

--****************
--* 3d functions *
--****************

-- based on 3d pico engine
-- by matheus mortatti

function update_engine()
	fps({lon,-alt/25,lat},pitch/360,heading/360)
end

function create_object(shape, pos, rh)
	local ns = {}
	ns.pos=pos
	ns.rh = rh
	--ns.points = shape ; not possible as ref to rwy is passed
	ns.points={}
	for p in all(shape) do
	 add(ns.points, {p[1],p[2],p[3],p[4]})
	end
	rotate_shape(ns.points, "y", ns.rh/360)
	add(objects, ns)
	return ns
end

--------------------------
-- draw functions
--------------------------

function draw_points(rwy)
 for p in all(rwy) do
  local c = p[4]
  local p1=mul_view(p)
  local x1,y1=project(p1)
  if p1[3]<-0.1 then -- clipping?
   if(y1<26) pset(x1,y1,c)
  end
 end
end  

function project(p)
	local x=abs(p[3])<=0.1 and 0 or -127/2*(p[1])/(p[3])+127/2
	local y=abs(p[3])<=0.1 and 0 or -26*(p[2])/(p[3])+10
	return x,y
end

-------------------------
-- linear algebra
-------------------------

function fps(eye,pitch,yaw)
	local cosp,sinp,cosy,siny=
			cos(pitch),sin(pitch),
			cos(yaw),sin(yaw)

	local x,y,z = {cosy,0,-siny},
				  {siny*sinp,cosp,cosy*sinp},
				  {siny*cosp,-sinp,cosp*cosy}

	viewmatrix = {
		{x[1],y[1],z[1],0},
		{x[2],y[2],z[2],0},
		{x[3],y[3],z[3],0},
		{-dot_product(x,eye),-dot_product(y,eye),-dot_product(z,eye),1}}
end

function mul_view(v)
	return {
	v[1]*viewmatrix[1][1] + v[2]*viewmatrix[2][1] + v[3]*viewmatrix[3][1] + viewmatrix[4][1],
	v[1]*viewmatrix[1][2] + v[2]*viewmatrix[2][2] + v[3]*viewmatrix[3][2] + viewmatrix[4][2],
	v[1]*viewmatrix[1][3] + v[2]*viewmatrix[2][3] + v[3]*viewmatrix[3][3] + viewmatrix[4][3],
	v[1]*viewmatrix[1][4] + v[2]*viewmatrix[2][4] + v[3]*viewmatrix[3][4] + viewmatrix[4][4],
			}
end

function dot_product(v1, v2)
	return v1[1]*v2[1] + v1[2]*v2[2] + v1[3]*v2[3]
end

function rotate_shape(s,a,r,c)
 for p in all(s) do
  rotate_point(p,a,r,c)
 end
end

function rotate_point(p,a,r,c)
	if c then
	  p[1]-=c[1]
	  p[2]-=c[2]
	  p[3]-=c[3]
	end
	local x,y,z=1,2,3

	if 		a=="z" then x,y,z=1,2,3
	elseif 	a=="y" then x,y,z=3,1,2
	elseif 	a=="x" then x,y,z=2,3,1
	end
  -- figure out which axis we're rotating on
  local _x = cos(r)*(p[x]) - sin(r) * (p[y]) -- calculate the new x location
  local _y = sin(r)*(p[x]) + cos(r) * (p[y]) -- calculate the new y location

  p[x] = _x
  p[y] = _y
  p[z] = p[z]

  if c then
	  p[1]+=c[1]
	  p[2]+=c[2]
	  p[3]+=c[3]
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
 

__gfx__
00000000fff7777faa777777777777ee5fffffff7fffffff77ff777fffffffff0000000000000000000000000000000000000000000000000000000000000000
00000000ff7fffffffffffffffffffff55fffffff7f7ffff7f7f777ffffffeff0000000000000000000000000000000000000000000000000000000000000000
00000000f7ffffffffbb77777777ddff555fffffff77ffff7f7f7f7feeeeeeef0000000000000000000000000000000000000000000000000000000000000000
000000007fffffffffffffffffffffff55fffffff777fffffffffffffffffeff0000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffcc7777ccffff5fffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
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
00000000fff55555ffffff55000fffff77ffffff7f7fffffff222fffff222fff0000000000000000000000000000000000000000000000000000000000000000
0000000055566666ffff5566070fffff7f7fffff7f7ffffff2eee2fff2eee2ff0000000000000000000000000000000000000000000000000000000000000000
0000000066655555ffff6655070fffff7f7fffff777fffff2eeeee2f2eee7e2f0000000000000000000000000000000000000000000000000000000000000000
0000000055555555ffff5555070fffff7f7fffff777fffff2777772f2ee7ee2f0000000000000000000000000000000000000000000000000000000000000000
0000000055500000ffff5500070fffffffffffffffffffff2eeeee2f2e7eee2f0000000000000000000000000000000000000000000000000000000000000000
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
0808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000600022223022230232002320024200242002320022200212002120021200212002120003700037000470004700057000570005700057000570005700057000470004700037000270002700027000170001700
