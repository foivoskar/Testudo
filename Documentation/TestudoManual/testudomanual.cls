\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{testudomanual}[2026/10/03 Testudo Modern User Manual Class]

\LoadClass[10pt,a4paper,oneside]{report}


% ============================================================
% ENGINE
% ============================================================

\RequirePackage{iftex}

\ifXeTeX
\else
    \ClassError
        {testudomanual}
        {This class requires XeLaTeX}
        {Compile using: latexmk -xelatex Testudo_manual.tex}
\fi


% ============================================================
% TYPOGRAPHY
% ============================================================

\RequirePackage{fontspec}

\defaultfontfeatures{
    Ligatures=TeX,
    Scale=MatchLowercase
}

% Primary typeface.
%
% Avenir Next gives the manual a native modern macOS feel.
% Helvetica Neue is the automatic fallback.

\IfFontExistsTF{Avenir Next}{
    \setmainfont{Avenir Next}
    \setsansfont{Avenir Next}
}{
    \setmainfont{Helvetica Neue}
    \setsansfont{Helvetica Neue}
}

% Terminal / file paths / code

\IfFontExistsTF{Menlo}{
    \setmonofont{Menlo}[
        Scale=0.82
    ]
}{
    \setmonofont{Courier New}[
        Scale=0.85
    ]
}

\renewcommand{\familydefault}{\sfdefault}

\RequirePackage{microtype}
\RequirePackage{setspace}
\RequirePackage{parskip}


% ============================================================
% PAGE GEOMETRY
% ============================================================

\RequirePackage[
    a4paper,
    top=20mm,
    bottom=22mm,
    inner=22mm,
    outer=22mm,
    headheight=18pt,
    headsep=8mm,
    footskip=13mm
]{geometry}

\setlength{\parindent}{0pt}
\setlength{\parskip}{6pt}

\setstretch{1.04}


% ============================================================
% CORE PACKAGES
% ============================================================

\RequirePackage{graphicx}

\RequirePackage[table]{xcolor}

\RequirePackage{array}
\RequirePackage{booktabs}
\RequirePackage{tabularx}
\RequirePackage{longtable}

\RequirePackage{enumitem}
\RequirePackage{listings}
\RequirePackage{xurl}

\RequirePackage{fancyhdr}
\RequirePackage{titlesec}
\RequirePackage{hyperref}
\RequirePackage{caption}

\RequirePackage{etoolbox}
\RequirePackage{tcolorbox}


% ============================================================
% TESTUDO DESIGN SYSTEM
% ============================================================

% Brand colours

\definecolor{TestudoBlue}{HTML}{2777A8}

\definecolor{TestudoDeepBlue}{HTML}{164664}

\definecolor{TestudoSoftBlue}{HTML}{EAF4FA}

\definecolor{TestudoPaleBlue}{HTML}{F5FAFD}

% Neutral palette

\definecolor{TestudoInk}{HTML}{182026}

\definecolor{TestudoText}{HTML}{303A40}

\definecolor{TestudoMuted}{HTML}{6D7880}

\definecolor{TestudoLine}{HTML}{DDE4E8}

\definecolor{TestudoSurface}{HTML}{F6F8F9}

\definecolor{TestudoWhite}{HTML}{FFFFFF}

% Semantic colours

\definecolor{TestudoGreen}{HTML}{34845A}

\definecolor{TestudoGreenSurface}{HTML}{EDF8F1}

\definecolor{TestudoOrange}{HTML}{C07824}

\definecolor{TestudoOrangeSurface}{HTML}{FCF5EA}

\definecolor{TestudoRed}{HTML}{B64B4B}

% Compatibility with commands already used by the .tex

\colorlet{TestudoDarkBlue}{TestudoDeepBlue}
\colorlet{TestudoLightBlue}{TestudoSoftBlue}
\colorlet{TestudoVeryLightBlue}{TestudoPaleBlue}
\colorlet{TestudoGray}{TestudoMuted}
\colorlet{TestudoLightGray}{TestudoLine}
\colorlet{TestudoDarkGray}{TestudoInk}


% ============================================================
% GLOBAL TEXT COLOUR
% ============================================================

\AtBeginDocument{
    \color{TestudoText}
}


% ============================================================
% HYPERLINKS
% ============================================================

\hypersetup{
    colorlinks=true,
    linkcolor=TestudoDeepBlue,
    urlcolor=TestudoBlue,
    citecolor=TestudoDeepBlue,
    pdfborder={0 0 0},
    bookmarksopen=true,
    bookmarksnumbered=true
}


% ============================================================
% LISTS
% ============================================================

\setlist[itemize]{
    leftmargin=1.55em,
    label=\textcolor{TestudoBlue}{\small\textbullet},
    itemsep=3pt,
    parsep=0pt,
    topsep=5pt
}

\setlist[enumerate]{
    leftmargin=1.8em,
    itemsep=4pt,
    parsep=0pt,
    topsep=5pt
}

\setlist[description]{
    leftmargin=0pt,
    itemsep=7pt,
    topsep=5pt,
    font=\bfseries\color{TestudoDeepBlue}
}


% ============================================================
% CHAPTER DESIGN
% ============================================================

\titleformat{\chapter}[display]
    {\normalfont}
    {
        \color{TestudoBlue}
        \fontsize{11}{13}
        \selectfont
        \bfseries
        \MakeUppercase{\chaptername}
        \hspace{0.5em}
        \thechapter
    }
    {7pt}
    {
        \color{TestudoInk}
        \fontsize{28}{31}
        \selectfont
        \bfseries
    }
    [
        \vspace{9pt}
        \color{TestudoBlue}
        \titlerule
    ]

\titlespacing*{\chapter}{
    0pt
}{
    -8pt
}{
    24pt
}


% ============================================================
% SECTION DESIGN
% ============================================================

\titleformat{\section}
    {
        \normalfont
        \fontsize{17}{21}
        \selectfont
        \bfseries
        \color{TestudoInk}
    }
    {\thesection}
    {0.65em}
    {}

\titlespacing*{\section}{
    0pt
}{
    20pt
}{
    8pt
}


\titleformat{\subsection}
    {
        \normalfont
        \fontsize{13}{17}
        \selectfont
        \bfseries
        \color{TestudoDeepBlue}
    }
    {\thesubsection}
    {0.6em}
    {}

\titlespacing*{\subsection}{
    0pt
}{
    16pt
}{
    5pt
}


\titleformat{\subsubsection}
    {
        \normalfont
        \fontsize{11}{14}
        \selectfont
        \bfseries
        \color{TestudoInk}
    }
    {\thesubsubsection}
    {0.55em}
    {}

\titlespacing*{\subsubsection}{
    0pt
}{
    13pt
}{
    4pt
}


% ============================================================
% HEADER / FOOTER
% ============================================================

\pagestyle{fancy}
\fancyhf{}

\fancyhead[L]{
    \fontsize{8.5}{10}
    \selectfont
    \bfseries
    \color{TestudoDeepBlue}
    TESTUDO
}

\fancyhead[R]{
    \fontsize{8.5}{10}
    \selectfont
    \color{TestudoMuted}
    \nouppercase{\leftmark}
}

\fancyfoot[L]{
    \fontsize{8}{10}
    \selectfont
    \color{TestudoMuted}
    User Manual
}

\fancyfoot[R]{
    \fontsize{8.5}{10}
    \selectfont
    \bfseries
    \color{TestudoDeepBlue}
    \thepage
}

\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}


\fancypagestyle{plain}{
    \fancyhf{}

    \fancyfoot[L]{
        \fontsize{8}{10}
        \selectfont
        \color{TestudoMuted}
        Testudo User Manual
    }

    \fancyfoot[R]{
        \fontsize{8.5}{10}
        \selectfont
        \bfseries
        \color{TestudoDeepBlue}
        \thepage
    }

    \renewcommand{\headrulewidth}{0pt}
    \renewcommand{\footrulewidth}{0pt}
}


% ============================================================
% TABLES
% ============================================================

\renewcommand{\arraystretch}{1.32}

\arrayrulecolor{TestudoLine}

\AtBeginEnvironment{longtable}{
    \small
}

\AtBeginEnvironment{tabularx}{
    \small
}


% ============================================================
% TERMINAL / CODE
% ============================================================

\lstdefinestyle{TestudoTerminal}{
    basicstyle=\ttfamily\fontsize{8.7}{12}\selectfont,
    backgroundcolor=\color{TestudoSurface},
    frame=l,
    rulecolor=\color{TestudoBlue},
    framerule=2.2pt,
    xleftmargin=1.0em,
    xrightmargin=0.6em,
    framexleftmargin=0.6em,
    aboveskip=10pt,
    belowskip=10pt,
    breaklines=true,
    breakatwhitespace=false,
    columns=fullflexible,
    keepspaces=true,
    showstringspaces=false
}

\lstset{style=TestudoTerminal}


% ============================================================
% MODERN INFORMATION CARDS
% ============================================================

\tcbset{
    testudocard/.style={
        boxrule=0pt,
        leftrule=3pt,
        arc=1.6mm,
        outer arc=1.6mm,
        boxsep=1mm,
        left=3mm,
        right=3mm,
        top=2.6mm,
        bottom=2.6mm,
        before skip=9pt,
        after skip=9pt,
        fonttitle=\bfseries,
        coltext=TestudoText
    }
}

\newcommand{\manualnote}[2]{%
    \begin{tcolorbox}[testudocard,colback=TestudoSoftBlue,colframe=TestudoBlue,coltitle=TestudoDeepBlue,title={#1}]
    #2
    \end{tcolorbox}%
}

\newcommand{\manualtip}[2]{%
    \begin{tcolorbox}[testudocard,colback=TestudoGreenSurface,colframe=TestudoGreen,coltitle=TestudoGreen,title={#1}]
    #2
    \end{tcolorbox}%
}

\newcommand{\manualwarning}[2]{%
    \begin{tcolorbox}[testudocard,colback=TestudoOrangeSurface,colframe=TestudoOrange,coltitle=TestudoOrange,title={#1}]
    #2
    \end{tcolorbox}%
}


% ============================================================
% SEMANTIC ELEMENTS
% ============================================================

\newcommand{\menu}[1]{
    \textbf{\color{TestudoInk}#1}
}

\newcommand{\button}[1]{
    \textbf{\color{TestudoDeepBlue}#1}
}

\newcommand{\fileext}[1]{
    \texttt{\color{TestudoDeepBlue}#1}
}

\newcommand{\filepath}[1]{
    \texttt{\color{TestudoDeepBlue}#1}
}

\newcommand{\term}[1]{
    \textbf{\color{TestudoInk}#1}
}

\newcommand{\Testudo}{
    \textbf{Testudo}
}


% ============================================================
% TABLE HELPERS
% ============================================================

\newcolumntype{Y}{
    >{\raggedright\arraybackslash}X
}

\newcolumntype{L}[1]{
    >{\raggedright\arraybackslash}p{#1}
}


% ============================================================
% CAPTIONS
% ============================================================

\captionsetup{
    font={
        small,
        color=TestudoMuted
    },
    labelfont={
        bf,
        color=TestudoDeepBlue
    },
    skip=6pt
}


% ============================================================
% CONTENT DEPTH
% ============================================================

\setcounter{tocdepth}{2}
\setcounter{secnumdepth}{3}


% ============================================================
% SMALL POLISH
% ============================================================

\emergencystretch=1.2em

\raggedbottom


\endinput
