// Generated from apps/verb_gym/specs/authoring authoring JSON.
// Keep source JSON files as the editable content format.

const List<String> defaultVerbConceptAuthoringJsonSources = <String>[
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "be_afraid",
    "meaning": {
      "en": {
        "short": "to be afraid",
        "description": "To feel fear."
      },
      "es": {
        "short": "tener miedo",
        "description": "Sentir miedo o temor."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo miedo."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I am afraid."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes miedo."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You are afraid."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene miedo."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He is afraid."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is afraid."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are afraid."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos miedo."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We are afraid."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis miedo."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You are afraid."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen miedo."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They are afraid."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You are afraid."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tuve miedo ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I was afraid yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tuviste miedo ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You were afraid yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tuvo miedo ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He was afraid yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She was afraid yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You were afraid yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tuvimos miedo ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We were afraid yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tuvisteis miedo ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You were afraid yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tuvieron miedo ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They were afraid yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You were afraid yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré miedo mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will be afraid tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás miedo mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will be afraid tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá miedo mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will be afraid tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will be afraid tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will be afraid tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos miedo mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will be afraid tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis miedo mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will be afraid tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán miedo mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will be afraid tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will be afraid tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "be_cold",
    "meaning": {
      "en": {
        "short": "to be cold",
        "description": "To feel cold."
      },
      "es": {
        "short": "tener frío",
        "description": "Sentir frío."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo frío."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I am cold."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes frío."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You are cold."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene frío."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He is cold."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is cold."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are cold."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos frío."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We are cold."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis frío."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You are cold."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen frío."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They are cold."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You are cold."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tuve frío ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I was cold yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tuviste frío ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You were cold yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tuvo frío ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He was cold yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She was cold yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You were cold yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tuvimos frío ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We were cold yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tuvisteis frío ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You were cold yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tuvieron frío ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They were cold yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You were cold yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré frío mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will be cold tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás frío mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will be cold tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá frío mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will be cold tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will be cold tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will be cold tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos frío mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will be cold tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis frío mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will be cold tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán frío mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will be cold tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will be cold tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "be_hungry",
    "meaning": {
      "en": {
        "short": "to be hungry",
        "description": "To feel that you want or need to eat."
      },
      "es": {
        "short": "tener hambre",
        "description": "Sentir necesidad de comer."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo hambre."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I am hungry."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes hambre."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You are hungry."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene hambre."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He is hungry."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is hungry."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are hungry."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos hambre."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We are hungry."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis hambre."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You are hungry."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen hambre."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They are hungry."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You are hungry."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tuve hambre ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I was hungry yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tuviste hambre ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You were hungry yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tuvo hambre ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He was hungry yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She was hungry yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You were hungry yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tuvimos hambre ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We were hungry yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tuvisteis hambre ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You were hungry yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tuvieron hambre ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They were hungry yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You were hungry yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré hambre mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will be hungry tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás hambre mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will be hungry tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá hambre mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will be hungry tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will be hungry tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will be hungry tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos hambre mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will be hungry tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis hambre mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will be hungry tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán hambre mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will be hungry tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will be hungry tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "be_right",
    "meaning": {
      "en": {
        "short": "to be right",
        "description": "To be correct."
      },
      "es": {
        "short": "tener razón",
        "description": "Estar en lo correcto."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo razón."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I am right."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes razón."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You are right."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene razón."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He is right."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is right."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are right."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos razón."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We are right."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis razón."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You are right."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen razón."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They are right."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You are right."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tuve razón ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I was right yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tuviste razón ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You were right yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tuvo razón ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He was right yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She was right yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You were right yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tuvimos razón ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We were right yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tuvisteis razón ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You were right yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tuvieron razón ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They were right yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You were right yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré razón mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will be right tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás razón mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will be right tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá razón mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will be right tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will be right tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will be right tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos razón mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will be right tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis razón mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will be right tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán razón mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will be right tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will be right tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "be_tired",
    "meaning": {
      "en": {
        "short": "to be tired",
        "description": "To feel tired or low on energy."
      },
      "es": {
        "short": "estar cansado",
        "description": "Sentir cansancio o falta de energía."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} estoy {adjective}."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "I am tired."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} estás {adjective}."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "You are tired."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} está {adjective}."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "He is tired."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "adjective": {
              "es": "cansada"
            },
            "text": {
              "en": "She is tired."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "You are tired."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} estamos {adjective}."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "We are tired."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} estáis {adjective}."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "You are tired."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} están {adjective}."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "They are tired."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "You are tired."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} estuve {adjective} ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "I was tired yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} estuviste {adjective} ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "You were tired yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} estuvo {adjective} ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "He was tired yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "adjective": {
              "es": "cansada"
            },
            "text": {
              "en": "She was tired yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "You were tired yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} estuvimos {adjective} ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "We were tired yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} estuvisteis {adjective} ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "You were tired yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} estuvieron {adjective} ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "They were tired yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "You were tired yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} estaré {adjective} mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "I will be tired tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} estarás {adjective} mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "You will be tired tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} estará {adjective} mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "He will be tired tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "adjective": {
              "es": "cansada"
            },
            "text": {
              "en": "She will be tired tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "adjective": {
              "es": "cansado"
            },
            "text": {
              "en": "You will be tired tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} estaremos {adjective} mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "We will be tired tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} estaréis {adjective} mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "You will be tired tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} estarán {adjective} mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "They will be tired tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "adjective": {
              "es": "cansados"
            },
            "text": {
              "en": "You will be tired tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "go_to_place",
    "meaning": {
      "en": {
        "short": "to go to a place",
        "description": "To move or travel toward a place."
      },
      "es": {
        "short": "ir a un lugar",
        "description": "Desplazarse hacia un lugar."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} voy al parque."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I go to the park."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} vas al parque."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You go to the park."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} va al parque."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He goes to the park."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She goes to the park."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You go to the park."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} vamos al parque."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We go to the park."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} vais al parque."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You go to the park."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} van al parque."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They go to the park."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You go to the park."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} fui al parque ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I went to the park yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} fuiste al parque ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You went to the park yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} fue al parque ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He went to the park yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She went to the park yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You went to the park yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} fuimos al parque ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We went to the park yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} fuisteis al parque ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You went to the park yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} fueron al parque ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They went to the park yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You went to the park yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} iré al parque mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will go to the park tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} irás al parque mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will go to the park tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} irá al parque mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will go to the park tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will go to the park tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will go to the park tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} iremos al parque mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will go to the park tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} iréis al parque mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will go to the park tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} irán al parque mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will go to the park tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will go to the park tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "have_age",
    "meaning": {
      "en": {
        "short": "to be a certain age",
        "description": "To express how old a person is."
      },
      "es": {
        "short": "tener una edad",
        "description": "Expresar la edad de una persona."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo veinte años."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I am twenty years old."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes veinte años."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You are twenty years old."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene veinte años."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He is twenty years old."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is twenty years old."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are twenty years old."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos veinte años."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We are twenty years old."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis veinte años."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You are twenty years old."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen veinte años."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They are twenty years old."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You are twenty years old."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré veinte años mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will be twenty years old tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás veinte años mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will be twenty years old tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá veinte años mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will be twenty years old tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will be twenty years old tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will be twenty years old tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos veinte años mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will be twenty years old tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis veinte años mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will be twenty years old tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán veinte años mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will be twenty years old tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will be twenty years old tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "have_possession",
    "meaning": {
      "en": {
        "short": "to have something",
        "description": "To possess, hold, or own something."
      },
      "es": {
        "short": "tener algo",
        "description": "Poseer, llevar o tener algo."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo un libro."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I have a book."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes un libro."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You have a book."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene un libro."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He has a book."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She has a book."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You have a book."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos un libro."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We have a book."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis un libro."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You have a book."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen un libro."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They have a book."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You have a book."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tuve un libro ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I had a book yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tuviste un libro ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You had a book yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tuvo un libro ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He had a book yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She had a book yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You had a book yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tuvimos un libro ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We had a book yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tuvisteis un libro ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You had a book yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tuvieron un libro ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They had a book yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You had a book yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré un libro mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will have a book tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás un libro mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will have a book tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá un libro mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will have a book tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will have a book tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will have a book tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos un libro mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will have a book tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis un libro mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will have a book tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán un libro mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will have a book tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will have a book tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "have_to_do",
    "meaning": {
      "en": {
        "short": "to have to do something",
        "description": "To express an obligation or necessity."
      },
      "es": {
        "short": "tener que hacer algo",
        "description": "Expresar obligación o necesidad."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tengo que estudiar hoy."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I have to study today."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tienes que estudiar hoy."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You have to study today."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tiene que estudiar hoy."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He has to study today."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She has to study today."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You have to study today."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tenemos que estudiar hoy."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We have to study today."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tenéis que estudiar hoy."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You have to study today."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tienen que estudiar hoy."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They have to study today."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You have to study today."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tuve que estudiar ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I had to study yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tuviste que estudiar ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You had to study yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tuvo que estudiar ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He had to study yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She had to study yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You had to study yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tuvimos que estudiar ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We had to study yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tuvisteis que estudiar ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You had to study yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tuvieron que estudiar ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They had to study yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You had to study yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} tendré que estudiar mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will have to study tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} tendrás que estudiar mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will have to study tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} tendrá que estudiar mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will have to study tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will have to study tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will have to study tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} tendremos que estudiar mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will have to study tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} tendréis que estudiar mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will have to study tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} tendrán que estudiar mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will have to study tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will have to study tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
  r'''{
  "schemaVersion": 1,
  "languages": ["en", "es"],
  "entry": {
    "id": "want_to_do",
    "meaning": {
      "en": {
        "short": "to want to do something",
        "description": "To express a desire or intention."
      },
      "es": {
        "short": "querer hacer algo",
        "description": "Expresar deseo o intención."
      }
    }
  },
  "examples": {
    "presentIndicative": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} quiero viajar mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} quieres viajar mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} quiere viajar mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He wants to travel tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She wants to travel tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} queremos viajar mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} queréis viajar mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} quieren viajar mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They want to travel tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You want to travel tomorrow."
            }
          }
        }
      }
    ],
    "preterite": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} quise viajar ayer."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I wanted to travel yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} quisiste viajar ayer."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You wanted to travel yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} quiso viajar ayer."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He wanted to travel yesterday."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She wanted to travel yesterday."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You wanted to travel yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} quisimos viajar ayer."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We wanted to travel yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} quisisteis viajar ayer."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You wanted to travel yesterday."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} quisieron viajar ayer."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They wanted to travel yesterday."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You wanted to travel yesterday."
            }
          }
        }
      }
    ],
    "futureSimple": [
      {
        "formGroup": {
          "es": "firstSingular"
        },
        "roles": ["I"],
        "pattern": {
          "es": "{subject} querré viajar mañana."
        },
        "variants": {
          "I": {
            "subject": {
              "es": "Yo"
            },
            "text": {
              "en": "I will want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondSingular"
        },
        "roles": ["You"],
        "pattern": {
          "es": "{subject} querrás viajar mañana."
        },
        "variants": {
          "You": {
            "subject": {
              "es": "Tú"
            },
            "text": {
              "en": "You will want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdSingular"
        },
        "roles": ["He", "She", "YouFormal"],
        "pattern": {
          "es": "{subject} querrá viajar mañana."
        },
        "variants": {
          "He": {
            "subject": {
              "es": "Él"
            },
            "text": {
              "en": "He will want to travel tomorrow."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She will want to travel tomorrow."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You will want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "firstPlural"
        },
        "roles": ["We"],
        "pattern": {
          "es": "{subject} querremos viajar mañana."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We will want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "secondPlural"
        },
        "roles": ["YouPlural"],
        "pattern": {
          "es": "{subject} querréis viajar mañana."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You will want to travel tomorrow."
            }
          }
        }
      },
      {
        "formGroup": {
          "es": "thirdPlural"
        },
        "roles": ["They", "YouPluralFormal"],
        "pattern": {
          "es": "{subject} querrán viajar mañana."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They will want to travel tomorrow."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You will want to travel tomorrow."
            }
          }
        }
      }
    ]
  }
}
''',
];
