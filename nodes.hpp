/*
**
*/

#include <string>
#include <map>
#include <set>
#include <vector>

/// Some containers
typedef std::vector<const class Node*> NodeList;
typedef std::vector<const class Arm*> ArmList;
typedef std::vector<const class Reference*> ReferenceList;

/// A set of ID's, which can have an optional value.
class IDSet
{
    IDSet(const IDSet& rhs);
    IDSet& operator=(const IDSet& rhs);
    typedef std::map<std::string, int> Items;
    Items mItems;
public:
    typedef Items::iterator iterator;
    IDSet(const std::string& id, int value=0)
    {
        mItems[id] = value;
    }
    bool has(const std::string& id) const
    {
        return mItems.find(id) != mItems.end();
    }
    void insert(const std::string& id, int value=0)
    {
        mItems[id] = value;
    }
    iterator begin() const
    {
        return const_cast<IDSet*>(this)->mItems.begin();
    }
    iterator end() const
    {
        return const_cast<IDSet*>(this)->mItems.end();
    }
};

/// Base class for all parse nodes
class Node
{
    Node(const Node& rhs);
    Node& operator=(const Node& rhs);
    const std::string* mName;
public:
    Node(const std::string* name)
        : mName(name)
    {
    }
    virtual ~Node()
    {
    }
    const std::string* Name() const
    {
        return mName;
    }
};

/// A simple declaration (of a primitive type)
class Simple : public Node
{
    int mType;
public:
    Simple(const std::string* name, int type)
        : Node(name), mType(type)
    {
    }
};

/// A named instance of a more complex type
class Reference : public Node
{
    const std::string* mRef;
    int mCrypto;
public:
    Reference(const std::string* name, const std::string* ref, int crypto=0)
        : Node(name), mRef(ref), mCrypto(crypto)
    {
    }
    const std::string& Ref() const
    {
        return *mRef;
    }
};

/// The arm of a select/variant
class Arm
{
    const IDSet* mCases;
    const ReferenceList* mReflist;
public:
    Arm(const IDSet* cases, const ReferenceList* reflist)
        : mCases(cases), mReflist(reflist)
    {
    }
    const IDSet& Cases() const
    {
        return *mCases;
    }
};

/// Constructed type -- struct, enum, variant/select
class Compound : public Node
{
    int mType;
    int mCrypto;
    union {
        const IDSet* uIDSet;
        const NodeList* uNodeList;
        const ArmList* uArmList;
    };
public:
    Compound(const std::string* name, int type, const IDSet* isp)
        : Node(name), mType(type), mCrypto(0), uIDSet(isp)
    {
    }
    Compound(const std::string* name, int type, const NodeList* nlp, int crypto=0)
        : Node(name), mType(type), mCrypto(crypto), uNodeList(nlp)
    {
    }
    Compound(const std::string* name, int type, const ArmList* alp)
        : Node(name), mType(type), mCrypto(0), uArmList(alp)
    {
    }
};

// Variables.
extern int lineno;

//  From flex.
extern char* yytext;
extern int yylex(void);

// From bison.
extern void vyyerror(const char* fmt, ...)
    __attribute__ ((format (printf, 1, 2)));
extern void setyydebug(bool flag);
