'use strict';

/* global View, WordCloud, __ */

var CanvasView = function CanvasView(opts) {
  this.load(opts, {
    name: 'canvas',
    element: 'wc-canvas',
    canvasElement: 'wc-canvas-canvas',
    hoverElement: 'wc-canvas-hover',
    hoverLabelElement: 'wc-canvas-hover-label'
  });

  window.addEventListener('resize', this);
  this.canvasElement.addEventListener('wordcloudstop', this);

  this.documentWidth = window.innerWidth;
  this.documentHeight = window.innerHeight;

  var style = this.canvasElement.style;
  ['transform',
   'webkitTransform',
   'msTransform',
   'oTransform'].some((function findTransformProperty(prop) {
    if (!(prop in style)) {
      return false;
    }

    this.cssTransformProperty = prop;
    return true;
  }).bind(this));

  this.idleOption = {
    fontFamily: 'Times, serif',
    color: 'rgba(255, 255, 255, 0.8)',
    rotateRatio: 0.5,
    backgroundColor: 'transparent',
    wait: 75,
    list: (function generateLoveList() {
      var list = [];
      var nums = [5, 4, 3, 2, 2];
      // This list of the word "Love" in language of the world was taken from
      // the Language links of entry "Cloud" in English Wikipedia,
      // with duplicate spelling removed.
      /*var words = ('Arai,Awan,Bodjal,Boira,Bulud,Bulut,Caad,Chmura,Clood,' +
        'Cloud,Cwmwl,Dampog,Debesis,Ewr,Felhő,Hodei,Hûn,Koumoul,Leru,Lipata,' +
        'Mixtli,Moln,Mây,Méga,Mākoņi,Neul,Niula,Nivulu,Nor,Nouage,Nuage,Nube,' +
        'Nubes,Nubia,Nubo,Nuvem,Nuvi,Nuvia,Nuvola,Nwaj,Nívol,Nóvvla,Nùvoła,' +
        'Nùvula,Núvol,Nûl,Nûlêye,Oblaci,Oblak,Phuyu,Pil\'v,Pilv,Pilvi,Qinaya,' +
        'Rahona,Rakun,Retë,Scamall,Sky,Ský,Swarken,Ulap,Vo\'e,Wingu,Wolcen,' +
        'Wolk,Wolke,Wollek,Wulke,dilnu,Νέφος,Абр,Болот,Болытлар,Булут,' +
        'Бұлттар,Воблакі,Облак,Облака,Хмара,Үүл,Ամպ,וואלקן,ענן,' +
        'ابر,بادل,بدل,سحاب,ورېځ,ھەور,ܥܢܢܐ,' +
        'ढग,बादल,सुपाँय्,মেঘ,ਬੱਦਲ,વાદળ,முகில்,' +
        'మేఘం,മേഘം,เมฆ,སྤྲིན།,ღრუბელი,ᎤᎶᎩᎸ,ᓄᕗᔭᖅ,云,雲,구름').split(',');*/
      var words = "white power,safe space,snowflake,triggered,libtard,uncivilised,gypo,c*nt,peckerwood,yellow bone,muzzie,n*gger,greaseball,white trash,nig nog,faggot,cotton picker,darkie,hoser,Uncle Tom,Jihadi,retard,hillbilly,fag,trailer trash,pikey,tranny,porch monkey,wigger,wetback,nigglet,wigga,dhimmi,honkey,eurotrash,yardie,trailer park trash,yokel,camel jockey,honkie,niglet,gyppo,dyke,half breed,honky,race traitor,jiggaboo,Chinaman,curry muncher,jungle bunny,newfie,house n*gger,limey,red bone,guala,plastic paddy,whigger,jigaboo,nig,Zionazi,spear chucker,yobbo,border jumper,sperg,pommy,munter,tar baby,pommie,gyp,anchor baby,twat,border hopper,queer,darky,ching chong,khazar,gippo,skanger,beaner,quadroon,gator bait,Cushite,mud shark,cracker,dune coon,pickaninny,slant eye,sideways vagina,hick,camel fucker,redneck,spiv,zipperhead,Kushite,Shylock,gook,papist,hymie,wog,scally,coon,whitey,nigette,paki,towel head,Argie,wexican,jigger,injun,ocker,polack,moulie,scanger,ofay,jigga,redskin,chonky,hebro,wop,chink,sideways pussy,paleface,wagon burner,nigra,spic,jocky,kraut,steek,coolie,gooky,octaroon,bint,shit heel,squaw,bog trotter,Oriental,halfrican,paddy,groid,jiggabo,jigg,jant,spide,camel humper,white n*gger,ZOG,diaper head,heeb,Christ killer,piker,higger,lemonhead,Hun,popolo,cowboy killer,jhant,eyetie,mockey,alligator bait,Jap,shanty Irish,mulignan,jockie,mangia cake,moulinyan,nigar,darkey,gurrier,lubra,Buckwheat,mulato,prairie n*gger,kyke,boonie,mick,bluegum,spigger,border bunny,kike,moulignon,roundeye,ginzo,Jewbacca,booner,nigre,scallie,niger,dinge,Leb,Lebbo,sambo,Africoon,ling ling,gub,banana bender,japie,island n*gger,hairyback,lugan,Bog Irish,blaxican,moke,nigor,bix nood,Kushi,guala guala,hoosier,mook,muk,soup taker,senga,Cushi,pogue,abo,ping pang,proddy dog,boong,dago,dogun,mocky,poppadom,Gwat,ice n*gger,spook,Afro-Saxon,guido,latrino,lowlander,mockie,moky,mosshead,African catfish,gyppy,timber n*gger,Americoon,camel cowboy,eh hole,Hunyak,slopehead,teabagger,Armo,bitch,greaser,Honyock,mud person,pineapple n*gger,retarded,semihole,Amo,border n*gger,buckra,burrhead,cab n*gger,carpet pilot,pancake face,spigotty,carrot snapper,chili shitter,curry slurper,ghetto hamster,ice monkey,roofucker,Velcro head,wiggerette,beach n*gger,bean dipper,bog hopper,Buddhahead,camel jacker,Caublasian,cave n*gger,cow kisser,dune n*gger,four by two,fresh off the boat,gin jockey,golliwog,guinea,Jim Fish,mackerel snapper,octroon,pohm,pussy,Russellite,spice n*gger,uncivilized,Whipped,albino,ape,Aunt Jemima,buckethead,Chinese wetback,chug,curry stinker,dyke jumper,eight ball,gun burglar,ikey mo,lawn jockey,leprechaun,mutt,negro,nitchee,sooty,spick,tinkard,uncircumcised baboon,zigabo,abbo,Anglo,Aunt Jane,Aunt Mary,Aunt Sally,azn,bamboo coon,banana lander,beaner shnitzel,beaney,Bengali,bhrempti,bird,bitter clinger,black Barbie,black dago,blockhead,bog jumper,boon,boonga,Bounty bar,boxhead,brass ankle,brownie,buffie,bug eater,buk buk,bumblebee,bung,bunga,butterhead,can eater,celestial,Charlie,chee chee,chi chi,chigger,chinig,chink a billy,chunky,clam,clamhead,colored,coloured,crow,dego,dink,dogan,dot head,eggplant,Fairy,fez,FOB,fog n*gger,fuzzy,fuzzy wuzzy,gable,Gerudo,gew,ghetto,gipp,gook eye,gyppie,heinie,ho,hoe,Honyak,Hunkie,Hunky,Hunyock,ike,ikey,iky,jig,jigarooni,jijjiboo,kotiya,mickey,moch,mock,mong,monkey,Moor,moss eater,moxy,muktuk,mung,munt,ned,net head,nichi,nichiwa,nidge,nip,nitchie,nitchy,Orangie,Oreo,papoose,piky,pinto,pointy head,pollo,pom,pommie grant,Punjab,rube,sawney,scag,seppo,septic,shant,sheeny,sheepfucker,Shelta,shiner,shit kicker,Shy,sideways cooter,skag,Skippy,slag,slant,slit,slope,slopey,slopy,smoke jumper,smoked Irish,smoked Irishman,sole,spickaboo,spig,spik,spink,squarehead,squinty,stovepipe,sub human,sucker fish,Taffy,teapot,tenker,tincker,tinkar,tinker,tinkere,trash,tree jumper,tunnel digger,Twinkie,tyncar,tynekere,tynkard,tynkare,tynker,tynkere,WASP,Yank,Yankee,yellow,yid,yob,zebra,zippohead,ZOG lover,knacker,shyster,bogan,hayseed,moon cricket,mud duck,surrender monkey,bludger,charver,dole bludger,chav,sheister,charva,touch of the tar brush,Northern monkey,Southern fairy,gubba,stump jumper,hebe,millie,quashie,dingo fucker,mil bag,conspiracy theorist,whore from Fife,boojie,book book,cheese eating surrender monkey,idiot,jock,mack,Merkin,neche,neejee,neechee,powderburn,proddywhoddy,proddywoddy,Rhine monkey".split(',');

      nums.forEach(function(n) {
        words.forEach(function(w) {
          list.push([w, n]);
        });
      });

      return list;
    })()
  };
};
CanvasView.prototype = new View();
CanvasView.prototype.TILT_DEPTH = 10;
CanvasView.prototype.beforeShow =
CanvasView.prototype.beforeHide = function cv_beforeShowHide(state, nextState) {
  switch (nextState) {
    case this.app.UI_STATE_SOURCE_DIALOG:
      if (state == this.app.UI_STATE_ABOUT_DIALOG) {
        break;
      }
      this.drawIdleCloud();
      break;

    case this.app.UI_STATE_LOADING:
    case this.app.UI_STATE_WORKING:
      this.empty();
      break;
  }
};
CanvasView.prototype.handleEvent = function cv_handleEvent(evt) {
  switch (evt.type) {
    case 'resize':
      this.documentWidth = window.innerWidth;
      this.documentHeight = window.innerHeight;

      break;

    case 'wordclouddrawn':
      if (evt.detail.drawn) {
        break;
      }

      // Stop the draw.
      evt.preventDefault();

      break;

    case 'wordcloudstop':
      this.canvasElement.removeEventListener('wordclouddrawn', this);

      break;

    case 'mousemove':
      var hw = this.documentWidth / 2;
      var hh = this.documentHeight / 2;
      var x = - (hw - evt.pageX) / hw * this.TILT_DEPTH;
      var y = (hh - evt.pageY) / hh * this.TILT_DEPTH;

      this.canvasElement.style[this.cssTransformProperty] =
        'scale(1.2) translateZ(0) rotateX(' + y + 'deg) rotateY(' + x + 'deg)';

      break;
  }
};
CanvasView.prototype.setDimension = function cv_setDimension(width, height) {
  var el = this.canvasElement;
  width = width ? width : this.documentWidth;
  height = height ? height : this.documentHeight;
  el.setAttribute('width', width);
  el.setAttribute('height', height);
  this.element.style.marginLeft = (- width / 2) + 'px';
  this.element.style.marginTop = (- height / 2) + 'px';
};
CanvasView.prototype.draw = function cv_draw(option) {
  // Have generic font selected based on UI language
  this.canvasElement.lang = '';

  this.hoverElement.setAttribute('hidden', true);
  option.hover = this.handleHover.bind(this);

  WordCloud(this.canvasElement, option);
};
CanvasView.prototype.handleHover = function cv_handleHover(item,
                                                           dimension, evt) {
  var el = this.hoverElement;
  if (!item) {
    el.setAttribute('hidden', true);

    return;
  }

  el.removeAttribute('hidden');
  el.style.left = dimension.x + 'px';
  el.style.top = dimension.y + 'px';
  el.style.width = dimension.w + 'px';
  el.style.height = dimension.h + 'px';

  this.hoverDimension = dimension;

  this.hoverLabelElement.setAttribute(
    'data-l10n-args', JSON.stringify({ word: item[0], count: item[1] }));
  __(this.hoverLabelElement);
};
CanvasView.prototype.drawIdleCloud = function cv_drawIdleCloud() {
  var el = this.canvasElement;
  var width = this.documentWidth;
  var height = this.documentHeight;

  // Only enable the rotation effect on non-touch capable browser.
  if (!('ontouchstart' in window)) {
    document.addEventListener('mousemove', this);
  }

  this.canvasElement.style[this.cssTransformProperty] = 'scale(1.2)';

  this.setDimension(width, height);
  this.idleOption.gridSize = Math.round(16 * width / 1024);
  this.idleOption.weightFactor = function weightFactor(size) {
    return Math.pow(size, 2.3) * width / 1024;
  };

  // Make sure Latin characters looks correct for non-English the UI language
  el.lang = 'en';

  // As soon as there is one word cannot be fit,
  // stop the draw entirely.
  el.addEventListener('wordclouddrawn', this);

  WordCloud(el, this.idleOption);
  this.hoverElement.setAttribute('hidden', true);
};
CanvasView.prototype.empty = function cv_empty() {
  document.removeEventListener('mousemove', this);
  this.canvasElement.style[this.cssTransformProperty] = '';

  WordCloud(this.canvasElement, {
    backgroundColor: 'transparent'
  });
};
