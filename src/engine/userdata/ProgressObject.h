#ifndef RIKO4_PROGRESSOBJECT_H
#define RIKO4_PROGRESSOBJECT_H


namespace riko::net {
    class ProgressObject {
    private:
        double currentAmt;
        double totalAmt;

    public:
        ProgressObject(double currentAmt, double totalAmt) : currentAmt(currentAmt), totalAmt(totalAmt) {}

        double getCurrentAmt() const {
            return currentAmt;
        }

        double getTotalAmt() const {
            return totalAmt;
        }
    };
}


#endif //RIKO4_PROGRESSOBJECT_H
