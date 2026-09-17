vcl 4.1;
import purge;
import std;
import vsthrottle;


backend default {
    .host = "nginx";
    .port = "8080";
}




sub vcl_backend_response {
    #pagina is 1 uur lang nieuw zonder request terug naar php voor refresh
    set beresp.ttl = 1h;
    
    #na het uur voorbij is mag varnish de pagina 12 uur lang nog uitdelen.
    set beresp.grace = 12h;
}


sub vcl_recv {

    # Beveiliging op specifieke niet cached paden
    if (req.url ~ "^/(user/login)") {
        if (vsthrottle.is_denied(client.ip + "", 900, 10s, 60s)) { #max 150 requests per 10 seconden indien meer 60 seconden block
            return (synth(429, "Too Many Requests")); #too many request returnen
        }
    }

        
    # Beveiliging op alle POST-verzoeken (formulieren omzeilen altijd de cache)
    if (req.method == "POST") {
        if (vsthrottle.is_denied(client.ip + "", 10, 10s, 30s)) { # meer dan 5 per 10s is 30s timeout
            return (synth(429, "Too Many Requests"));
        }
    }

        #geeft https info door aan drupal 
    if (req.http.X-Forwarded-Proto == "https") {
        set req.http.X-Forwarded-Port = "8443";
    }

    #sla ingelogde gebruikers over 
    if (req.http.Cookie ~ "SESS|SSESS") {
        return (pass);
    }

    if  (std.port(local.ip) == 80) {
        if (req.method == "PURGE" || req.method == "BAN") {
            return (synth(405, "Not allowed"));
        }
    }

    if (std.port(local.ip) == 8081) {
        if (req.method == "PURGE"){
            return (hash);
        }
        if (req.method == "BAN")
        {
           if  (!req.http.X-Drupal-Cache-Purge-Tags){
            return (synth(400, "Bad request: missing X-Drupal-Cache-Purge-Tags header."));
           } 
           ban("obj.http.X-Drupal-Cache-Tags ~ " + req.http.X-Drupal-Cache-Purge-Tags);
           return(synth(200, "Banned"));
        }


    }
}

# Soft purging uitvoeren wanneer het object gevonden is
sub vcl_hit {
    if (req.method == "PURGE") {
        purge.soft();
        return (synth(200, "Soft Purged"));
    }

    if (std.healthy(default)) { #hou oud mag pagina zijn als backend healthy/unhealthy is.
        set req.grace = 10ms;
    } else {
        set req.grace = 2h;
    }
}

#voor wanneer het object niet gevonden word in de cache.
sub vcl_miss {
    if (req.method == "PURGE") {
        purge.soft(); #Op deze manier is ttl op maar blijft die nog in cache voor grace
        return (synth(404, "Not in cache"));
    }

    #Beveiliging: Maximaal 60 cache misses per 10 seconden per bezoeker-IP
    if (vsthrottle.is_denied(client.ip + "", 60, 10s, 30s)) {
        return (synth(429, "Too Many Requests - Cache Miss Limit Exceeded"));
    }

    return (fetch);
}

sub vcl_deliver {
    unset resp.http.X-Drupal-Cache-Tags; #cache tags niet naar browser van user
}


