# Формат данных для изучения времен глаголов

Данные для изучения времен глаголов хранятся в следующем формате: **authoring JSON**.

Этот формат предназначен для удобного хранения, редактирования и генерации учебных данных. Из него на этапе сборки можно получить runtime JSON, где все примеры уже развернуты по лицам, временам и языкам.

Поля `schemaVersion`, `languages`, `roles`, `tenses`, `formGroups` являются справочниками. Справочники перечислены ниже.

## Общая идея формата

Базовой сущностью является не глагол, а **смысловая карточка**.

Например:

```text
to be hungry
to be cold
to have something
to be 20 years old
to have to do something
```

Для испанского эти смыслы могут выражаться через один и тот же глагол `tener`, но это разные учебные конструкции:

```text
tener hambre
tener frío
tener algo
tener veinte años
tener que hacer algo
```

Такой подход позволяет не привязывать данные к языковой паре `Spanish-English`. Английский может использоваться как один из языков описания, но не является единственным источником данных.

## Основная структура

```json
{
  "schemaVersion": 1,
  "languages": ["en", "es", "ru"],
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
      },
      "ru": {
        "short": "быть голодным",
        "description": "Чувствовать голод, хотеть есть."
      }
    }
  },
  "examples": {
    "presentIndicative": [
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
              "en": "He is hungry.",
              "ru": "Он голоден."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is hungry.",
              "ru": "Она голодна."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are hungry.",
              "ru": "Вы голодны."
            }
          }
        }
      }
    ]
  }
}
```

## Поля верхнего уровня

### `schemaVersion`

Версия схемы данных.

```json
"schemaVersion": 1
```

Используется для будущих изменений формата.

### `languages`

Список языков, которые используются в карточке.

```json
"languages": ["en", "es", "ru"]
```

Поле справочное. Оно помогает быстро понять, какие локализации присутствуют в файле.

### `entry`

Смысловая карточка.

```json
"entry": {
  "id": "be_hungry",
  "meaning": {
    "en": {
      "short": "to be hungry",
      "description": "To feel that you want or need to eat."
    }
  }
}
```

### `entry.id`

Технический идентификатор смысла.

Примеры:

```text
be_hungry
be_cold
be_tired
be_afraid
be_right
have_possession
have_age
have_to_do
want_to_do
go_to_place
```

Идентификатор удобно писать на английском, в `snake_case`.

## Стартовый список понятий для генерации

Генератор учебных данных должен начать с этих смысловых карточек:

```text
be_hungry
be_cold
be_tired
be_afraid
be_right
have_possession
have_age
have_to_do
want_to_do
go_to_place
```

Каждый пункт из списка становится стабильным `entry.id`. Это именно понятия,
а не глаголы: один и тот же глагол в конкретном языке может обслуживать
несколько разных понятий.

### `entry.meaning`

Локализованное описание смысла.

```json
"meaning": {
  "en": {
    "short": "to be hungry",
    "description": "To feel that you want or need to eat."
  },
  "es": {
    "short": "tener hambre",
    "description": "Sentir necesidad de comer."
  },
  "ru": {
    "short": "быть голодным",
    "description": "Чувствовать голод, хотеть есть."
  }
}
```

### `meaning.<language>.short`

Короткое значение.

Используется в списках, карточках и быстрых подсказках.

### `meaning.<language>.description`

Более подробное объяснение смысла.

Используется в справке, объяснениях и учебных экранах.

## Справочник языков

Коды языков задаются по ISO-подобной схеме:

```text
en  English
es  Spanish
ru  Russian
de  German
fr  French
it  Italian
```

Необязательно, чтобы все языки были заполнены для каждой записи.

## Справочник ролей

Роль описывает грамматическую роль в универсальном виде, а не конкретную форму в испанском.

Рекомендуемый базовый набор:

```text
I
You
He
She
It
We
YouPlural
YouFormal
YouPluralFormal
They
```

Пример для испанского:

```text
I                 yo
You               tú
He                él
She               ella
YouFormal         usted
We                nosotros / nosotras
YouPlural         vosotros / vosotras
YouPluralFormal   ustedes
They              ellos / ellas
```

Важно: роли не надо объединять только потому, что в каком-то языке формы совпадают.

Например, в испанском:

```text
él tiene
ella tiene
usted tiene
```

Форма глагола одинаковая, но роли разные:

```text
He
She
YouFormal
```

Это важно для других языков и для нормальных переводов.

## Справочник времен

Ключи времен используются в объекте `examples`.

Рекомендуемый стартовый набор:

```text
presentIndicative
presentPerfect
preterite
imperfectIndicative
futureSimple
conditionalSimple
presentSubjunctive
imperfectSubjunctive
```

Пример:

```json
"examples": {
  "presentIndicative": [],
  "preterite": [],
  "imperfectIndicative": []
}
```

Описание времен хранится отдельно, в справочнике приложения:

```json
{
  "presentIndicative": {
    "name": {
      "en": "Present indicative",
      "es": "Presente de indicativo",
      "ru": "Настоящее время изъявительного наклонения"
    },
    "description": {
      "en": "Used for present facts, habits and current states.",
      "ru": "Используется для фактов, привычек и текущих состояний."
    }
  }
}
```

В файле примеров это описание не дублируется.

## Справочник групп форм

`formGroup` показывает, какая грамматическая форма используется в конкретном языке.

Например, для испанского:

```json
"formGroup": {
  "es": "thirdSingular"
}
```

Пример справочника для испанского:

```text
firstSingular    yo
secondSingular   tú
thirdSingular    él / ella / usted
firstPlural      nosotros / nosotras
secondPlural     vosotros / vosotras
thirdPlural      ellos / ellas / ustedes
```

Это позволяет сохранить разные роли, но не дублировать одинаковую грамматическую форму.

Например:

```json
{
  "formGroup": {
    "es": "thirdSingular"
  },
  "roles": ["He", "She", "YouFormal"]
}
```

Это означает:

```text
He         él tiene
She        ella tiene
YouFormal  usted tiene
```

Форма `tiene` одна, но роли разные.

## Формат примеров

Примеры хранятся внутри `examples`.

```json
"examples": {
  "presentIndicative": [
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
            "en": "He is hungry.",
            "ru": "Он голоден."
          }
        }
      }
    }
  ]
}
```

### `formGroup`

Группа формы для одного или нескольких языков.

```json
"formGroup": {
  "es": "thirdSingular"
}
```

В будущем можно добавить другие языки:

```json
"formGroup": {
  "es": "thirdSingular",
  "fr": "thirdSingular"
}
```

### `roles`

Список ролей, к которым применяется этот блок примеров.

```json
"roles": ["He", "She", "YouFormal"]
```

### `pattern`

Шаблон фразы на изучаемом языке.

```json
"pattern": {
  "es": "{subject} tiene hambre."
}
```

Шаблон нужен, чтобы не дублировать почти одинаковые фразы.

Из шаблона:

```text
{subject} tiene hambre.
```

и значения:

```json
"subject": {
  "es": "Él"
}
```

получается:

```text
Él tiene hambre.
```

### `variants`

Отличия для конкретных ролей.

```json
"variants": {
  "He": {
    "subject": {
      "es": "Él"
    },
    "text": {
      "en": "He is hungry.",
      "ru": "Он голоден."
    }
  }
}
```

Каждый ключ внутри `variants` должен соответствовать одной из ролей из `roles`.

### `subject`

Значение для подстановки в шаблон.

```json
"subject": {
  "es": "Él"
}
```

В будущем можно добавлять другие переменные:

```json
{
  "subject": {
    "es": "Él"
  },
  "object": {
    "es": "una manzana"
  }
}
```

Тогда шаблон может быть таким:

```json
"pattern": {
  "es": "{subject} tiene {object}."
}
```

### `text`

Переводы готовой фразы на другие языки.

```json
"text": {
  "en": "He is hungry.",
  "ru": "Он голоден."
}
```

Испанский текст здесь не нужен, если он генерируется из `pattern`.

## Пример полной карточки

```json
{
  "schemaVersion": 1,
  "languages": ["en", "es", "ru"],
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
      },
      "ru": {
        "short": "быть голодным",
        "description": "Чувствовать голод, хотеть есть."
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
              "en": "I am hungry.",
              "ru": "Я голоден."
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
              "en": "You are hungry.",
              "ru": "Ты голоден."
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
              "en": "He is hungry.",
              "ru": "Он голоден."
            }
          },
          "She": {
            "subject": {
              "es": "Ella"
            },
            "text": {
              "en": "She is hungry.",
              "ru": "Она голодна."
            }
          },
          "YouFormal": {
            "subject": {
              "es": "Usted"
            },
            "text": {
              "en": "You are hungry.",
              "ru": "Вы голодны."
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
          "es": "{subject} tenemos hambre después del paseo."
        },
        "variants": {
          "We": {
            "subject": {
              "es": "Nosotros"
            },
            "text": {
              "en": "We are hungry after the walk.",
              "ru": "Мы голодны после прогулки."
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
          "es": "{subject} tenéis hambre después de la clase."
        },
        "variants": {
          "YouPlural": {
            "subject": {
              "es": "Vosotros"
            },
            "text": {
              "en": "You are hungry after the class.",
              "ru": "Вы голодны после урока."
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
          "es": "{subject} tienen hambre porque han caminado mucho."
        },
        "variants": {
          "They": {
            "subject": {
              "es": "Ellos"
            },
            "text": {
              "en": "They are hungry because they have walked a lot.",
              "ru": "Они голодны, потому что много ходили."
            }
          },
          "YouPluralFormal": {
            "subject": {
              "es": "Ustedes"
            },
            "text": {
              "en": "You are hungry because you have walked a lot.",
              "ru": "Вы голодны, потому что много ходили."
            }
          }
        }
      }
    ]
  }
}
```

## Runtime JSON делает следующее

Runtime JSON разворачивает authoring JSON в готовые учебные примеры.

```json
{
  "entryId": "be_hungry",
  "examples": {
    "presentIndicative": {
      "He": [
        {
          "es": "Él tiene hambre.",
          "en": "He is hungry.",
          "ru": "Он голоден."
        }
      ],
      "She": [
        {
          "es": "Ella tiene hambre.",
          "en": "She is hungry.",
          "ru": "Она голодна."
        }
      ],
      "YouFormal": [
        {
          "es": "Usted tiene hambre.",
          "en": "You are hungry.",
          "ru": "Вы голодны."
        }
      ]
    }
  }
}
```

Сборщик должен:

1. взять `pattern`;
2. взять переменные из `variants`;
3. подставить переменные в шаблон;
4. развернуть блок по ролям;
5. сохранить готовые фразы в runtime-формате.

## Основные правила валидации

1. Каждый `entry.id` должен быть уникальным.
2. Каждый ключ в `examples` должен существовать в справочнике времен.
3. Каждая роль из `roles` должна существовать в справочнике ролей.
4. Каждый ключ в `variants` должен быть перечислен в `roles`.
5. Все переменные из `pattern`, например `{subject}`, должны быть определены в соответствующем `variant`.
6. Для каждого учебного примера должен быть текст на изучаемом языке после подстановки шаблона.
7. Переводы на другие языки могут отсутствовать.

## Ключевая идея

Формат не хранит “перевод глагола”. Он хранит:

```text
смысл
  -> как этот смысл выражается в разных языках
  -> учебные примеры по временам
  -> роли, для которых форма совпадает
  -> шаблон фразы
  -> отличия для конкретных ролей
```

Это позволяет избежать языковых пар, уменьшить дублирование и сохранить точность для языков, где грамматические формы отличаются.
