cron, drush gebruiken ipv via gui instellen, multisite op drupal niveau, verschill tussen domain site 

# Poorten 8080 en 8443
Deze hebben geen root rechten nodig op macos de 80 en 443 wel dus niet elke applicatie gebruikt deze dus om het simpel te houden gewoon deze gebruikt.

# redis
commando voor controleren of het werkt: docker compose exec redis redis-cli monitor

# cronjob
┌───────────── minuut (0 - 59)
│ ┌─────────── uur (0 - 23)
│ │ ┌───────── dag van de maand (1 - 31)
│ │ │ ┌────── maand (1 - 12)
│ │ │ │ ┌──── dag van de week (0 - 6) (Zondag = 0)
│ │ │ │ │
* * * * *  /pad/naar/script.sh

Gebruikt voor specific taken te laten uitvoren op specifieke momenten.

#Drush

Drupal shell is een CLI voor drupal.

Waarom?
Is veel sneller dan via de interface. Bv bij cache clearen.
Zware taken zoals database migratie of cronjob uitvoeren kan via GUI vastlopen. Via de CLI is dit meer betrouwbaar.
Belangrijkste is dat het conmmandos werkt dus je kan het met een cronjob op specifieke momenten laten uitvoeren.

Paar Drupal commnands
- drush cr --> cache rebuild dit wist en rebuild de caches (Indien redis is ingesteld deze ook)
- drush cron --> Voor alle achtergrond taken handmatig uit.
- drupal pm:enable modulenaam --> schakelt een specifieke drupal module in.
- drush status --> toont informatie ver drupal versie, settings, database status
- drush uli --> Genereert een eenmalige inloglink voor de beheerderaccount.
- drush updatedb --> Voert database update uit.
- ....

# Drush samen met cron gebruiken

Drupal heeft van zichzelf al voorgemaakte onderhoudsinstructies die er standaard mee inzitten.
Zoals het indexeren van zoekfunctie of het deleten van oude logs of het legen van redis cache.
Dit roep je aan met het drush cron comamndo. Hiermee doet hij de basis cleanup processen die je dan om de zoveel tijd kan laten lopen.

Ik heb hiervoor een cron container aagemaakt. Ik heb een entrypoint script dat word gerunt in deze container die dan de crond deamon opstart.
Deze deamnon voert elke 15 minuten van de dag het commando van de crontab file uit en dit commando triggered dan de drupal core die dan die standaard onderhoud commandos uitvoert. 
Deze stuurt dan naar de andere containers in dit netwerk dat ze dit moeten doen.

controleren of het is of word uitgevoerd met: ddocker compose logs cron

# Health Checks
Health checks heb ik toegevoegd om te kijke of een instance wel echt goed werkt hoe het hoort en dat dan andere containers wachten tot een container waar ze vanaf hangen healthy is opgestart.
Je kan dit makkelijk testen door het commando te veranderen naar false in dat geval denkt het dat het commando een fout returned. 

# Resource management
Het instellen van minimum en max resources dat een container mag gebruiken. 
Zodat een container zeker genoeg resources heeft of er niet te veel gebruikt.
In dit scenario gaan de recources van mijn laptop natuurlijk niet op geraken maar is het gewoon best practice voor als er een container zoals die van postgresql die bij het opstarten ook wel wat resources nodig heeft ze zeker heeft.

# Multisite
Ingebouwde feature van Drupal. Meerdere verschillende site kunnen hosten met dezelfde broncode. Ze hebben wel gescheiden databases en configuraties. 
Dit werkt op een manier dat als de gebruiker naar bv siteA.com gaat het verzochte domein dan die specifieke instellingen ophaalt en verbindt met database van die site.
Dit maakt updaten sneller en het heeft minderschijfruimte nodig im totaal en makkelijker voor centraal beheer. 
Het nadeel is wel dat er een Single point of failure hebt want 1 php issue in de code en de gekoppelde websites ligt ook plat.
Geen individuele modules per websites zijn mogelijk want als de code er is voor de ene website is deze er ook voor de andere.
Dit maakt database migratie wel lastiger. Het loskopelen van 1 specifieke website om deze te verhuizen kost meer werk. 
- 1 codebase
- voor elke site een database


#Domain site
Wanneer meerdere domeinnamen worden aangestuurd vanaf 1 drupal installatie.
Het werkt zo maar met 1 database voor meerdere domains en hetzelfde drupal systeem. 
Dus stel als je een gebruiker hebt staat deze in de database voor alle websites in principe want deze gebruiken allemaal dezelfde. Dus beetje het SSO verhaal 1 keer inloggen voor meerdere websites.                  
Dit betekent dat er meerdere sites gekoppeld zijn aan 1 codebase en 1 database.
Het voordeel hieraan is dat je hebt weer een centraal beheer punt. Kan makkelijk content hergebruiken. Je hebt maar 1 database voor te back upen dus dit is ook meer maintainable. 
- 1 codebase
- 1 database voor meerdere websites

flow van requests blijft bij beide hetzelfde tot aan de PHP container.
Bij mutlisite
- HTTP header word doorgegeven aan de PHP container
- Die vind een match en kijkt dan in de sites map voor de settings.php
- En dan word er verbinding gemaakt met de juiste database.
- Hiervoor geef je een extra volume mee aan postgres container waarin je 2 databases maakt 1 voor elke multisite. 


Bij domain site
- Laadt de standaard settings.php
- verbind met de database (Er is er maar 1)
- Hier word dan een query gedaan naar het juiste domain id voor het juiste op te halen.

Wat gebeurd er met redis?
- Bij multisite gebruiken ze allemaal dezelfde redis dus dan moet er een cache prefix worden ingesteld. (In een aparte folder onder sites met in de settings.php onderaan de prefix)
- Anders zou site a misschien de opgeslagen paginas ophalen van site b

- Bij Domain site regelt drupal zelf dat cache keys het domain id bevatten omdat het 1 grote site is.


Samenvatting multisite
Implementeren van multi site voeg je eerst 2 mappen to in de web/sites folder met dan de naam van de multisite dat je gebruikt. dan daarin voeg je een settings.php toe en kan je dan de default settings kopieren.
Je past aan deze default file dan aan dat deze een prefix gebruikt voor redis omdat anders de 2 sites niet gaan weten wat van wie is.  " $settings['cache_prefix']['default'] = 'ms_a_';" dit is daar de oplossing voor.
Ik heb dan een kleine initialise SQL file gemaakt dat bij het opstarten van postgres dan 2 aparte databases maakt. 1 per multisite.

Deze voeg je toe aan de volumes van de postgres container "- ./docker/postgres/init-multisite.sql:/docker-entrypoint-initdb.d/init-multisite.sql" met de juiste mapping.

De nginx config file moet ook iets extra aan toegevoegd worden zodat het deze domain names kent. "server_name localhost *.local multisite-a.local multisite-b.local domain-a.local domain-b.local;" (domain sites volgen later)

Voor domain site hoef je niet veel te doen je moet gewoon in de settings.php deze bijplaatsen 

"include_once DRUPAL_ROOT . '/' . $modules_path . '/domain/domain.module';" --> Hierdoor is de juiste module aanwezig voor de domain site te kunnen gebruiken.


# SSL certificate
Lokaal met mkcert heb ik self signed certificates gemaakt en deze dan aan de nginx container gegeven.
Ook even de nginx config aangepast waardoor deze ook verkeer kan binnenkrijgen op poort 8443 voor https verkeer en dat de tls protocolen ondersteund zijn.

ook even in de sites.php folder gezet want anderes ging deze geen requests kunnen krijgen op de poort en met https.

#Multiple stage build
Dockerfile aangepast door een base image van alpine te gebruiken.
Deze instaleert dan de redis extensie voor php zodat deze met redis kan samenwerken.
Een app gedeelte dat dan de drupal php image gebruikt.
Ook een cron gedeelte dat specifiek is voor de cron container.



# varnish
Is een caching systeem dat HTML paginas en elemeten kan cachen dus eigenlijk een beetje zoals redis maar dan voor front end elementen.
Varnish gebruikt RAM voor dit in op te slaan hierdoor is het snel ophaalbaar.
De varnish container komt voor de nginx container terecht. Dus als je naar de website gaat dit eerst langs daar tenzij je https gebruikt dan gaat het eerst naar nginx.
Nginx moet namelijk eerst het pakket uitpakken en dan de html ervan doorgeven aan varnish voor de cache

Varnish slaat deze html elementen of voledige paginas op in het RAM geheugen van de container. Hierdoor is het snel op te halen.
Het weet wanneer het dingen moet opslagen aan de hand van de unieke hash van de hostnaam plus de exacte URL van de pagina. 
In de huidige config werkt het met al het HTTP verkeer gaat direct naar varnish en het HTTPS verkeer omdat dit met self signed certificates werkt moet het eerst naar NGINX en dan als het daar is uitgepakt word het doorgestuurd naar de varnish container.
Je kan ook het aantal hits en miss zien in de varnish container met het commando "docker compose exec varnish varnishstat -f MAIN.cache_hit -f MAIN.cache_miss -f MAIN.s_pass"
Goed tegen ddos op server niveau.

De verschillende Varnish Action returns:
Hash --> Zoekt in RAM of de opgevraagde pagina al in de cache staat. Voor normale paginas die gecached mogen worden.
Pass --> Slaat de cach over en stuurt request naar drupal of nginx. (Bijvoorbeeld bij login page)
pipe --> Sluit de varnish verwerking en maakt een direct pipeline tussen bezoeker en backend. (Voor veel grote downloads)
Purge --> Voor het verwijderen van een specifieke pagina of object uit de cache. (Als een pagina of element is aangepast)
Restart --> Herstart de verwerking van het hele HTTP request vanaf het begin. (request url is herschreven of failover backend)
Deliver --> Stuurt response uit cache vanaf backend naar bezoeker. (Aan het einde van een response)
Ban --> maakt een pagina in cache ongeldig aan de hand van specifieke patronen zoals bv een map /nieuws of een specifieke drupal cache tag

# ESI (Edge Side Includes)
Hierdoor kan varnish paginas opknippen en terug samenvoegen op server-niveau
Wanneer er een stukje van een pagina dynamisch is word dit moeilijk te cachen terwijl de rest van de pagina wel gewoon hetzelfde is voor iedereen.
ESI lost dit op door dit dynamische deel apart door te sturen met een esi html tag.
Varnish herkend deze tag en haalt de rest van de pagina uit zijn cache. hierdoor doet varnish alleen een kleine request intern en plakt de react dan in de gecachte pagina.
Dus alles van deze pagina is bespaard buiten die 1 procent die dan moest worden opgehaald.

Moet wel door de developers zijn gebruikt in html tags want anders gaat het niet weten welke hier toe behoren en welke niet en dan niets doen.


# Soft purge
Word in de varnish docs genoemt als grace mode en dit wilt zeggen als een pagina in de varnish cache word gesoft purged dan is deze aangegeven als verlopen maar nog niet verwijderd. Deze word nog even bijgehouden.
Waarom is dit nodig? Wanneer je een pagina net hebt gepurged en er dan plots 100 mensen naar die specifieke pagina gaan dan gaan al deze requests van varnish naar de php container gestuurd hierdoor is het veel trager en in sommige gevallen crashed het.
Dus iedereen die dan plots naar die website gaat krijgt dan de oude gezien tot de nieuwe ook gecached word en dan is er eigenlijk geen enkel moment dat de gebruiker niets kan zien.



# Streaming
Normaal werkt varnish volgens buffer and store wanneer er een pagina niet in de cache staat.
Varnish verstuurt het verzoek naar drupal. Varnish wacht tot drupal de volledige HTML-pagina klaar heeft en naar varnish heeft verzonden
Wanneer het bestand volledig binnen is slaat varnish het bestand op in de cache en stuurt het in 1 keer naar de bezoeker.
Hierdoor ziet de gebruiker secondenlang een wit scherm omdat varnish staat te wachten.

Varnish streaming lost dit op door een soort doorgeefluik te zijn in real time.
drupal begint te genereren van de pagina en stuurt de eerste paar bytes (html <Head>) naar varnish
varnish neemt deze eerste head en stuurt ze direct door naar de bezoeker 
De browser van de bezoeker kan meteen beginnen met het inladen van de CSS, JS, images
terwijl varnish de rest van de pagina streaming doorgeeft aan de bezoeker saat hij de bytes tegelijkertijd op in de cache.

Het lost problemen op met dat de bezoeker wanneer een pagina NIET gecached is lang moet wachten.
Zorgt er ook voor dat niet het hele bestand al ingeladen moet zijn bij varnish voor het kan beginnen met downloaden bij de bezoeker.
Stel meedere gebruikers hebben diezelfde pagina of bestand nodig op hetzelfde moment dan kunnen ze gebruik maken van dezelfde stream.

streaming is standaard al true set beresp.do_stream = true; dus deze optie staat zonder dat je iets doet al aan.

# Health Checks
Je hebt health checks van varnish die checken de drupal/php instance.
Hierdoor wanneer deze zou wegvallen kan het overgaan op cache en de paginas die nog gecached staan gebruiken. 
Hierdoor moet dit aanstaan want anders weet varnish niet dat hij dit moet doen dan probeert hij gewoon deze pagina te refreshen.
voor die healthcheck gebruik ik op het moment / als page om te checken normaal gezien moet het gedaan worden met een static file of health module.

docker compose exec varnish varnishadm backend.list --> check met dit commando

# VMOD
Je kan import gebruiken in vcl (varnish config) en daarmee kan je voorgemaakte functies downloaden en gebruiken die het makkelijker maken dan dit volledig met de basis syntax te schrijven.

# DDOS bescherming met varnish
standaard zorgt varnish hier passief al voor door het cachen van frondend elemeten en paginas die dan niet meer opgehaald moeten worden. 
Nu dit kan soms niet genoeg zijn door dat ze heel specifieke queries gaan aanroepen die dit dan toch triggered.
Je kan via varnish nog altijd rate limiting apart toevoegen nu dit is anders dan die van haproxy omdat haproxy niet weet wat er in de cache zit het ziet alleen inkomende requests.

Stel je hebt 200 requests maar dit is het ophalen van een gecachte pagina dan heeft dit niet zoveel impact maar stel het is een NIET gecachte pagina dan heb je een serieus probleem.
Dit is eigenlijk wat je via varnish nog verder kan beheren.

De option forward for werkt niet voor dit. Waarom?  het ip adres van een gebruiker kan worden gespooft dit kan niet mij de proxy manier want dit word afgedwongen door het netwerk protocol
de forward optie stuurt gewoon een header mee en dit kan je vervalsen.

ik heb dit ingesteld als je max 10 verzoeke per 10 seconden per uniek ip adres. Hierdoor kan je dan je de niet gecachte paginas niet de hele tijd opvragen.

# Cache tag
Word geplakt aan een gecachte pagina en geven aan uit welke losse onderdelen dat deze pagina bestaat.
Stel je hebt een nieuws pagina dan staan hier een paar artikelen op en stel je past 1 van die artikelen aan.
Je zou de URL moeten wissen maar dit artikel staat ook gecacht op de homepage op de categorieen pagina en in de zoekresultaten daar blijft de oude content staan.
Je wist de hele varnish cache dus ALLE paginas ook al hebben deze er niet mee te maken worden verwijderd. Je server krijgt hierdoor ineens een zware piek omdat er zoveel tegelijk veranderd word.

Dit lost cache tags op wanneer de persoon nu dit artikel aanpast kijkt het naar welke tag hangt hieraan en dan word alles verwijderd waar dit etiket mee aan vasthangt.
hierdoor word alles dat te maken heeft met die pagina dus niet ALLES dat in de varnish cache te vinden was.


# Haproxy
Heel snelle open source high availability load balancer en reverse proxy.
Het controleert continue de gezondheid van de achterliggende servers met health checks en stuurt het verkeer naar de healthy servers. 
Het kan HTTPS decryption afhandelen op de voorgrond (Zoals nginx)
Het kan verkeer sturen op basis van ip adressen maar ook op basis van HTTP data URL's cookies of headers.
Is ook heel goed tegen DDoS aanvallen. Slaat in geheugen hoeveel requests per IP adres al zijn gebeurd en aan de hand van deze gegevens word dan dit IP adres geratelimit of geblokkeerd. 
Slow read attacks (Aanval waarbij een aanvaller de connectie heel lang openhoudt door heel traag http headers te sturen) Als haproxy niet het volledige verzoek ontvangt binnen de zoveel miliseconden dan word de connectie verbroken.
Werkt ook goed als buffer want kan heel grotea aantallen tcp connecties hebben zonder te crashen.
Heeft ook geoblocking en controleert HTTP headers voor correcte syntax. (Bot nets gebruiken vaak oudere software versies hiermee kan het dit opvangen.)

Stick tables is iets dat Haproxy gebruikt voor te onthouden welke ip adressen nu requests hebben gedaan en deze word gecleared om de zoveel tijd hierdoor kan het makkelijk zien welke er te veel requests doen.
Je kan er de size van meegeven, de expire na hoeveel tijd deze er terug uitmag, en het belangrijkste wat het voor elk ip adres moet bijhouden in deze tabel.
Het ip adres is hier de key van de tabel.

Paar beschermings functies ook toegevoegd.
Wanneer er iemand binnen de 50 seconden meer als 50 requests doet dan krijgt dit ip adres een timeout waarna de 50 secondne deze terug ui de sticktable gaan.
Je kan dit checken door "or i in {1..60}; do curl -s -i -k https://multisite-a.local:8443 | grep "HTTP/"; done" dan zul je zien dat na de zoveelste request hier een too many requests opkomt.

Buiten dat als er user agent: als header staat dan word dit ook geblocked. Waarom? Omdat deze header vaak gebruikt word in botnets.
Ook zijn een paar andere namen geblokeert zoals sqlmap nikto zgrab python-requests deze zijn ook veel voorkomend bij botnets. 

commandos om dit mee te testen:


# Geoblocking met haproxy
Door een lijst van IP adres ranges mee te geven kan je requests van deze rangesn blokeren. 
Dit kan Haproxy goed omdat het helemaal vooraan staat en daar alles binnenkomt.



# HA proxy healthy checks
gebeuren onderaan bij de config file daar kan je check inter Xs voor hoeveel seconden er tussen elke check moet zitten.
Dan kan je DOWN en RISE kiezen voor te zeggen hoeveel keer na elkaar ze up of down moeten zijn voor healthy of unhealthy.
Deze health checks zijn niet hetzelfde als de docker health checks deze zijn er voor te kijken of er verkeer naar kan worden gestuurd de normale docker health checks zijn gemaakt voor of de container herstart moet worden.
Dus bij docker word de container als unhealthy verklaart of herstart en bij Haproxy health checks word deze gewoon niet meer gebruikt voor verkeer naar te sturen.

# HTTP 2 EN HSTS
Zorgt voor snellere laadtijden door multiplexing van browser requests.
Wegens de multiplexing kan per TCP verbinding maar 1 request tegelijk komen. 
het gebruikt binaire dataframes in plaats van tekstgebaseerde protocol.




files folder per site apart krijgen 
wat gebeurd er als je een entrypoint gebruikt ? Van waar komen je images wat voor entrypoint gebruiken deze. 

# permission issues
Stel er geraakt op een manier toch iemand binnen in je container/vm  en de service die daar draait draait via de root user dan heeft de persoon die daar binnen root acces en dat willen we natuurlijk niet.
Wat is de oplossing?  We laten de service daarbinnen niet als root draaien maar we maken een user die net genoeg access heef om dat te doen of sommige images hebben hiervoor al een user die je met een nummer kan aanroepen in de docker compose file.
Sommige kan je dit beste doen via een eigen image hiervan te maken die dan een user heeft n bepaalde installaties doet met die user of mappen aanmaakt.
Sommige images hebben ook specifieke secure versions zoals die nginx.
Heb dit ook aangepast door sommige containers volledig read only te maken hierdoor kan je er niets op doen van schrijven tenzij er een volume aan gekoppeld is waar wel read writ recthen op staan.
Permission issues bij cron komen ook voor wanneer dit de drush cron uitvoerd als www-data dan is er schrijfrechten nodig op de files map van de site, de tmp map en de drush runtime map
Drush doet cache bestanden weg en verwerkt  tijdelijke uploads en feeds hierdoor moet die aan de /files kunnen van de site. Samen met de /tmp wegens dat deze nodig is voor het tijdelijk wegschrijven van log files.


# file permission issues
Denk ik in orde met de www-data user en dan de websites die gescheiden staan per folder in /sites morgen navragen aan yannick
Voor de rest nog verdere uitbreiding vragen aan yannick. 
Ook checken van https_in morgen ochtend en toevoegen van use_backend daar door dat de ene multi site niet werkt.


# Init container en runtime container
Je kan in plaats van een container read only te maken en dan te strugglen met permission issues een runtime en init container maken.
Dit zorgt ervoor dat alles wat je moet runnen op runtime al is het restoren van database of cache of migraties dan kan je dit hierop doen.
Achteraf kan je dan dit volume mounten op de runtime container met read only priveleges zodat dan alles eigenlijk klaar is. Hierna exit de init container dan.
Hierdoor kan je dan zonder issues op runtime wel een read only veilige container hebben zonder issues te hebben met die permissions. 
In mijn huidige setup runt deze 4 cache rebuild commandos en dan wanneer dit gelukt is word het gemount op de runtime container en dan word de init container afgesloten.

# HAproxy domain maps
Hierbij gebruik je een aparte file voor domains te koppelen aan een backend en wanneer er dan een pakket binnenkomt.
Dan word dit doorgestuurd naar de juiste backend of anders naar de default als die is ingesteld.

#HAproxy voor meerdere clusters van containers gebruiken
Bij het maken van 2 clusters kan je 1 haproxy gebruiken voor al het binnenkomend verkeer naar de sites toe. 
Zorg ervoor dat deze op de host draait en gebruik dan 2 aparte docker compose files (Ik gebruik 1 dezelfde maar met a en b varianten van dezelfde containers) en zorg ervoor dat de volumes die naar de sites gaan niet door elkaar heen gemount worden. 
Hierdoor kan je perfect de 2 clusters apart van elkaar beheren en toch via 1 haproxy gaan.

# HAproxy domain maps


domain mapping voor ha proxy 
opsplitsen van docker compose zodat je 2 aparte netwerken heeft met 1 gezamelijke haproxy
container die init doet en andere die dezelfde volume mount maar dan ro

# HSTS
Beveiligings header waarmee een webserver browsers dwingt de website alleen met https te openen.
Dit beschermt tegen man in the middle attacks en cookie hijacking.
Vaak sneller omdat er niet eerst in HTTP word gestuurd en dan naar https word geredirect.

# PURGE AND BAN block van buitenaf
ingeschakeld dat alleen PURGE en BAN werken met de internal port 8081 en vanaf buitenaf kan je deze niet uitvoeren.
Dit is veiliger want dan is er geen mogelijkheid dat er iemand op een manier het ip adres van een allowed container kan spoofen.

# Beveiliging van nginx paden voor bepaalde paden en files
Rate limiting zou je ook vanaf nginx kunnen doen maar haproxy is in dit geval veel beters geschikt daarvoor.
Nu nginx kan wel nog bepaalde directories of files afblocken van requests omdat deze container verbonden is met de php instance en daardoor met het file system hiervan.
Hierdoor kan het iets wat haproxy in dit geval niet kan doen. Nu security issues kunnen nog altijd uit drupal zelf komen maar dan kan dit komen door de developer.

# Redis tegenover varnish
Ze werken op 2 heel verschillende plekken van elkaar.
Redis werkt achter php binnen drupal en cached vooral php data, db queries, configuratie en losste html fragments
Varnish staat voor nginx en php dus staat buiten de applicatie en cached volledige http responses en compleste html, css, js van een pagina.
Varnish heeft heel veel impact op database en de backend. Waarom? Als een pagina gecached is dan zien de backend en database de request vaak niet eens omdat het dan
van user naar haproxy naar varnish en dan direct aan de user word gegeven. 
Redis heeft impact op php vooral omdat het deze cache overneemt en hierdoor 

# Monitoring toevoegen
Toevoegen van prometheus kan via het koppelen aan netwerk van cluster a en b en dan aan het newerk van haproxy.
Hierdoor kan hij haproxy en beide clusters monitoeren of alles goed gaat.


# PostgreSQL parameters voor Drupal.   

shared_buffers: geheugen voor db cache (Best 25% van je ram)
effective_cache_size: schatting van geheugen dat beschikbaar is voor cache (Best 50% tot 75% van je ram)
work_mem: geheugen per query operation voor sorts, joins voor drupal tussen de 16 en 64 MB
maintenance_work_mem: geheugen voor onderhoudstaken zoals indexen bouwen tussen 256MB EN 1GB
random_page_cost: bepaalt hoe zwaar database query planner een disk page read weegt (standaard is dit 4.0, voor SSD’s zet je dit lager 1,1)
checkpoint_completion_target: spreidt het wegschrijven van transacties over langere periode zodat performance stabiel blijft (0.9)
autovacuum: opgeruimde records direct uit tabellen halen.

Dit kan je of als commando laten uitvoeren op je container bij je docker compose file of je zet dit in een config file die je mee mount aan je container.
Deze config file is een pak cleaner.

# Redis parameters voor Drupal

maxmemory: bepaalt de hard limit van RAM dat er gebruikt mag worden. Zonder deze limit kan redis alles gebruiken wat er beschikbaar is.
maxmemory-policy: bepaalt wat er gebeurd als de maxmemory word bereikt
save "" : Normaal gezien schrijft redis kopieen van data naar schijf zodat deze na een restart nog aanwezig zijn, maar omdat drupal cache uitsluitend in het geheugen hoeft te zijn kan je dit best leeg laten.
lazyfree-lazy-eviction / lazyfree-lazy-expire : Als deze op yes staan wist redis verlopen of grote cache files asynchroon op de achtergrond. Hierdoor zal je minder snel max memory krijgen.

die geef je ook best mee in een config file genaamd redis.conf
hierin zet je dan je values je mount deze aan de container en dan moet je nog even deze conf file uitvoeren met command: en dan is het klaar.



# Varnish via CDN? wat is dat? 
Je kan varnish self hosten of je kan het via CDN bv fastly.
Wat is het verschil? Als je het self host dan draait het op je eigen server en ga je cachen van je eigen server je moet het zelf instaleren en is beperkt to de capacity van je eigen server. Je gaat direct via lokaal netwerk naar de varnish.
CDN is dat je varnish niet zelf moet hosten het draait op honderden verschillende servers rond de hele wereld. Je roept het aan via API en je hebt geen volledige controle over deze varnish. Deze is ideaal voor grotere sites en als je over de hele wereld klanten hebt. Want
je snelheid is door dit edge netwerk toch wel wat sneller dan als je het zelf zou hosten.

# Varnish memory management
Voor varnish kan je best ook memory management instellen. Want standaard kan het heel veel RAM gebruiken.
Je kan dit meegeven via default.vcl op de parameter -s malloc,256m
Of je kan dit meegeven via docker compose command: command: varnishd -F -a :80,PROXY -f /etc/varnish/default.vcl -s malloc,256m 
Hier bij dit voorbeeld is het gelimiteerd tot 256 MB.




# memory management / limit voor php bekijken 
Voor PHP is het ook belangrijk dat dit word ingesteld.
Je kan een php.ini file gebruiken hiervoor. Dit dan mounten aan de container.
Waarom niet standaard laten? 
Standaard staan deze limits te laag en kan drupal niet goed werken met deze limieten, zeker omdat drupal redelijk veel geheugen verbruikt.
Bijvoorbeeld bij een drush commando dat best veel geheugen kan verbruiken dan ga je snel in de foutlimiet zitten waardoor je niet verder geraakt.

Voorbeelden parameters in php.ini:
memory_limit: hoeveel geheugen php mag gebruiken bv 512m
max_execution_time: hoe lang een script mag draaien bv 60
max_input_time: hoe lang een script mag draaien bv 60
upload_max_filesize: hoeveel een upload mag zijn bv 128m
post_max_size: hoeveel post mag zijn bv 128m

# OPcache geheugen beheer
opcache.enable=1: opcache aanzetten
opcache.memory_consumption: hoeveel geheugen opcache mag gebruiken bv 512m
opcache.interned_strings_buffer: hoeveel geheugen opcache mag gebruiken bv 32m
opcache.max_accelerated_files: hoeveel bestanden opcache mag cachen bv 10000
opcache.validate_timestamps: of opcache op timestamps moet controleren bv 1
opcache.revalidate_freq: hoe vaak opcache op timestamps moet controleren bv 0


# instaleren van umami website zonder memory issue 
Het vorige lost dit probleem eigenlijk al op je hebt omdat umami image downloaden best groot is niet genoeg memory hiervoor.
Hierdoor kan je een error krijgen zoals php Fatal error:  Allowed memory size of 536870912 bytes exhausted (tried to allocate 2097152 bytes) in /var/www/html/web/core/lib/Drupal/Core/DependencyInjection/ContainerBuilder.php on line 1386
Dit kan je oplossen met memory_limit mee te sturen in het commando maar is niet aangeraden omdat de settings dan eigenlijk fout staan ingesteld.


# SOLR bekijken wat is dat? Bereiken via solr localhost/website via https 

Solr is een open source enterprise search platform. gebouwd op apache lucene en is speciaal ontworpen om super snel grote hoeveelheden data te doorzoeken, indexeren, filteren.
Je kan ermee full text search doen, faceted search, fuzzy search, woordstammen, em zoekresultatten sorteren op relevantie score.
Faceted search: Hiermee bouw je filters, bijvoorbeeld op prijs, kleur, merk, categorie.
Hoge prestaties / schaalbaarheid: solr draait als een aparte zoekdienst en bewaart een geoptimaliseerd zoekindex in het geheugen.
Standaard gebeurt communcatie met solr via HTTP of via JSON of XML

In een omgeving met drupal gebeurd dit normaal met standaard ingebouwde SQL zoekfunctie maar dit is super traag en veel resource vragend voor je instance.
De search API Solr module van drupal zorgt ervoor dat de zoekfuncties worden afgehandeld door een solr container.
Dit is veel sneller, database moet niet zoveel werk doen, betere zoek ervaring want je krijg functies zoals autocompletion tijdens het typen.

Waar moet je op letten bij self hosting van solr?
- Solr draait op java en gebruikt snel 1 tot 4 GB ram van je server
- Zelf verantwoordelijk voor updates van solr, java, backups van de index.
- Je moet configuratie bestanden van drupal zelf mounten aan de container
- Je moet zelf de module Search API Solr installeren en configureren in Drupal.
- Je moet de solr core via een browser of via terminal configureren.
- Je krijgt zelf URL om te connecten met drupal en om te browsen in solr.bv:  http://[IP_ADDRESS]/solr/#/drupal

We gaan voor deze config gebruik maken van 1 instance die dan 1 index gebruikt per cluster voor resources te besparen. 2 containers 1 per cluster is beetje overkill hier
We gaan werken met een init solr container die based is op een busybox en want solr heeft bepaalde write rechten nodig om zijn cores te maken. Deze init container word daarna weer weggegooid. 
Nu we willen ook graag met https naar dit dashboard gaan dus een extra certificate maken voor deze is nodig. "mkcert -pkcs12 -p12-file solr-ssl.keystore.p12 localhost solr 127.0.0.1 ::1"

verder kijken naar zookeeper
# instellen dat je daar een core hebt? Drupal heet mjet drupal configs in en je krijgt extra punten als je connectie hebt met je drupal site en dit kan gebruiken.
Het instellen van een core per multisite in Solr.
Een core is een individuele afgezonderde zoekindex binnen een solr server met een eigen configuratie en dataset.
Elke multisite krijgt zijn eigen core. Je moet dit koppelen in drupal en wanneer dit kan gebeurd is krijg je een config bestand.
Je krijgt er eentje per multisite en dan moet je dit uipakken en mounten aan de container. Deze config word dan gebruikt voor deze core.
Hier connecteren deze dan via de manier dat je hebt ingesteld en praat dan zo met die solr. Ik heb het gedaan met https maar krijg het probleem niet opgelost dat drupal niet wilt verbinden. 
Dit komt dat het certificaat niet betrouwbaar is volgens drupal dus moet je dit opgelossen krijgen met de juiste instellingen te veranderen. 

De vier Drupal-sites verbinden nu met hun Solr-core via HTTPS.
De oorzaak was de hostnaam: het actieve certificaat bevat solr, terwijl Drupal verbinding maakte met central_solr. Via https://solr:8983 werkte certificaatcontrole al correct.
Ik heb alleen de vier settings.php-bestanden aangepast:
- Solr-host gewijzigd van central_solr naar solr.
- verify = FALSE en de geforceerde TLS-instelling verwijderd.
- Bij sites A/B de foutieve databasehost teruggezet van postgres-b naar postgres-a.
De essentiële wijziging is:
$config['search_api.server.central_solr']['backend_config']['connector_config']['host'] = 'solr';
central_solr blijft hier de Drupal-server-ID; alleen de verbindingshost verandert.
Gecontroleerd: alle vier cores antwoorden OK, Drupal meldt ze beschikbaar en alle vier websites geven 200. Nieuwe certificaten of een image-rebuild waren niet nodig.
Bij de extra croncontrole vond ik nog een afzonderlijk probleem: Search API wordt daar niet correct geladen. De HTTPS-verbinding zelf werkt ook vanuit cron; dat moduleprobleem valt buiten deze gerichte TLS-fix.

Nu moeten we nog indexen maken. 

bij indexes heb je verschillende data sources. Wat je doorzoekbaar wilt maken.
Je hebt de tracker. De tracker is gemaakt om te onthouden welke pagina's nieuw zijn en welke bewerkt zijn of verijderd moeten worden.
Indexing order is welke content het eerst aan de buurt komt als er veel artikelen tegelijk klaarstaan voor de zoekindex.

Je hebt ook nog extra index options voor het bepalen van content dat daarwekelijk fysiek naar solr gestuurd word.

Ik heb als test hier een search index gemaakt die gekoppeld is aan de solr server.
Dan een paar field zoals title en body gemapped met fulltext datatype.


# Google cloud



# VM verbinden met internet zonder public IP
Je kan dit doet door google cloud NAT te gebruiken voor je subnet. Je moet wel een external ip aan deze NAT toevoegen.
Een VM zonder public IP kan via deze NAT wel naar het internet connecteren. 
Deze NAT kan dan ook weer verkeer doorsturen. 
Om dit te configureren heb je een eigen subnet nodig met private ip's en een compute engine met google cloud nat. 
Je moet voor je compute engine wel een vpc netwerk hebben. 

Voor simuleren van deze omgeving in gcp maar het kosten efficient houden ga ik werken met containers binnen een vm.
Dus deze 1 vm gaat mijn docker compose file runnen. 
Nu voor het ip adres verhaal heb ik dan een vpc nodig. die dan verbind met de google router en dan google nat.
Maar deze nat heeft dan wel een static ip adres nodig.

cloud nat --> cloud router --> vpc --> subnet --> vm

Uitgaand verkeer:
Pakket verstuurd vanuit vm --> VPC routing ziet dat het op internet is --> CLOUD NAT --> Stript internal ip voor een google public ip  --> Cloud nat houdt dit bij in mapping table --> internet

Inkomend verkeer:
 Pakket komt aan bij google public ip --> Cloud nat kijkt naar mapping table --> Kijkt welk internal ip adres --> schrijft terug het interne ip als destination --> VM

Probleem?
Cloud nat doet niet aan port forwarding: pakket komt aan op poort .. en stuur het dan door naar ... dit word niet ondersteund door google NAT.
Hierdoor is het niet mogelijk om op een manier via de nat gateway http of https traffic te sturen naar de webserver (vm)

Je kan dus ook op geen enkele manier naar de website surfen. 

Er is wel een manier om je website te zien met IAP.
Identity-Aware Proxy(IAP) is een verificatie en autorisatie infrastructuur die draait aan de rand van google cloud.
Dit zorgt er voor dat je je applicatie kan beveiligen met google accounts en groep. En dat je kan connecteren op een veilige manier. 
Zelf kan je dan je verkeer gaan doorsturen naar je vm via een local port forwarding. 
Hierdoor kan je normaal wel op de website.

Wat voor vm?
ik denk dat 2 vcpu 6 gb ram en 10 gb wel voldoende moet zijn.

# NFS

Network file system is nog niet nodig wanneer er maar 1 vm aanwezig is zoals nu.
Maar wanneer er een tweede word toegevoegd is dit wel cruciaal. Het is belangrijk zodat bestanden die moeten gedeelt worden door meerdere vms hier ook allemaal aan kunnen.

voor later ....


# Load balancer

Internal load balancer 
--> Bedoelt voor het verdelelen van traffic onder verschillende microservices.
--> Intern ip adres uit het vpc waarin deze staat.
--> Niet zichtbaar voor de buitenwereld

External load balancer
--> gebruikt een publiek ip adres
--> verdeelt het verkeer over verschillende webservers.
--> kan ook https afhandelen, https terminatie, https end-to-end, ddos bescherming.


Application load balancer
--> bovenste laag, begrijpt applicatie protocolen zoals http, https, 
--> heeft context aware routing dus kan bepaalde request naar bepaalde servers sturen.
--> handelt ssl termination af of ssl end to end 
--> VM ziet het ip adres van de container want deze maakt direct verbinding en ip adres van deze gebruiker word mee geforward.

Passthrough load balancer
--> laag 4 , geen http
--> werkt als super snelle router, stuurt heel snel pakketjes door naar de juiste backend vm.
--> Ziet het originele ip adres van de gebruiker want deze wordt meegestuurd
--> Heeft geen https afhandeling dus de vm naar waar het verstuurd word moet dit afhandelen.
--> Heel low latency dus als er heel snelle responses verwacht worden is dit perfect.
--> Vooral geschikt voor niet HTTPS verkeer, directe database connecties, redis, websockets.

ingress:

firewall ingress:

Op netwerk niveau zorgt ingres ervoor dat verkeer vanaf buitenaf een VPC, subnet, VM binnenkomt in je omgeving.
Bijvoorbeeld: Als je een IAP ingress rule instelt voor inkomend verkeer op ip adres en poort 22 dat dit binnen mag komen.
Of bij load balancers een ingress rule dat die alleen de range ip adressen van de 

Kubernetes ingress

Als het niet op een enkele VM draait maar met container orchestration werkt zoals Kubernetes is ingress
een specifiek api object dat de ingang van de hele cluster beheert.
In plaats van losse micro services of op container niveau een eigen load balancer maken  maak je een ingress resource.
Dit luistert naar dit object en maakt automatisch 1 centrale external load balancer aan deze stopt het verkeer door naar de juiste containers binnen de cluster te gaan.
Hoe?
--> host based routing: multisite a word naar pod a gestuurd multisite b naar pod b
--> Path based routing: /media gaat naar de storage container /search naar solr
--> ssl/tls termination: centraal afhandelen van SSL certificaten voor meerdere domeinen.

Soorten vm's

- General purpose
C4, C4D, N4, N4D, N2, N2D, C3, C3D, E2, T2D, N1
algemene workloads en normale verhouding tussen cpu en memory
bestaan uit verschillende samenstellingen van specs

- Compute optimized





drupal core toevoegen. NETWERKEN scheiden want deze staan niet juist ingesteld. varnish van elk netwerk gelinkt met haproxy in hun eigen netwerk en dan apart 



# AANMAKEN VPC

drupal-net met subnet drupal-subnet-euw1 met range 10.0.1.0/24
Private google acces on --> voor vanuit private vm zonder public ip naar google services te sturen